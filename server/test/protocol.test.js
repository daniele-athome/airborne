/**
 * The envelope.
 *
 * `parseEnvelope` is the other half of the surface an unauthenticated caller can
 * reach: it runs before `authenticate`, on a body that is whatever arrived over
 * the wire. Two things matter here. That every malformed shape produces a JSON
 * refusal rather than an exception — the deployment answers anonymously, and an
 * uncaught throw would leak a stack trace where a code belongs. And that the
 * order of the checks holds, because the order is what decides how much an
 * unknown caller learns about the server before proving anything.
 */

const {describe, it} = require('node:test');
const assert = require('node:assert/strict');

require('./load.js');

const TOKEN = 'af71c0e2';

/**
 * A readable name for a value in a test title.
 *
 * `JSON.stringify` turns both NaN and null into "null", which would give two
 * cases in the same loop the same name and make a failure report point at the
 * wrong one.
 */
function label(value) {
    if (value !== value) {
        return 'NaN';
    }
    if (value === undefined) {
        return 'undefined';
    }
    return JSON.stringify(value);
}

/** A well-formed body, with `overrides` applied on top. */
function body(overrides) {
    return Object.assign({
        v: PROTOCOL_V,
        token: TOKEN,
        action: 'flight-log/insert',
        requestId: 'req-1'
    }, overrides);
}

/** The same body with one of its keys absent rather than undefined. */
function bodyWithout(key) {
    const value = body();
    delete value[key];
    return value;
}

function assertRejected(result, code, pattern) {
    assert.equal(result.envelope, undefined, 'expected a refusal, got an envelope');
    assert.equal(result.error.ok, false);
    assert.equal(result.error.error.code, code);
    if (pattern) {
        assert.match(result.error.error.message, pattern);
    }
}

function accepted(result) {
    assert.equal(result.error, undefined, 'expected an envelope, got: ' + JSON.stringify(result.error));
    return result.envelope;
}

describe('parseEnvelope: the body itself', () => {
    for (const notAnObject of [null, undefined, '', 'a string', 7, true]) {
        it('refuses ' + label(notAnObject), () => {
            assertRejected(parseEnvelope(notAnObject), ERROR.BAD_REQUEST, /must be a JSON object/);
        });
    }

    it('gets as far as the version check on an array', () => {
        // `typeof [] === 'object'`, so an array is not caught by the shape check
        // and falls through to the version, which it does not have. Same refusal
        // in the end, by a different road.
        assertRejected(parseEnvelope([]), ERROR.BAD_REQUEST, /non-integer "v"/);
    });
});

describe('parseEnvelope: version', () => {
    for (const bad of [undefined, '1', 1.5, NaN, null]) {
        it('refuses a version of ' + label(bad), () => {
            assertRejected(parseEnvelope(body({v: bad})), ERROR.BAD_REQUEST, /non-integer "v"/);
        });
    }

    it('tells a client that is too old which version is required', () => {
        const result = parseEnvelope(body({v: PROTOCOL_V_MIN - 1}));
        assertRejected(result, ERROR.PROTOCOL_INCOMPATIBLE, /requires at least v/);
    });

    it('tells a client that is too new which version is supported', () => {
        const result = parseEnvelope(body({v: PROTOCOL_V_MAX + 1}));
        assertRejected(result, ERROR.PROTOCOL_INCOMPATIBLE, /supports up to v/);
    });

    it('keeps the two version messages distinct', () => {
        // An app that is behind must update itself; a server that is behind must
        // be redeployed. One code, two different things to do about it.
        assert.notEqual(
            parseEnvelope(body({v: PROTOCOL_V_MIN - 1})).error.error.message,
            parseEnvelope(body({v: PROTOCOL_V_MAX + 1})).error.error.message
        );
    });

    it('refuses an infinite version as unsupported', () => {
        assertRejected(parseEnvelope(body({v: Infinity})), ERROR.PROTOCOL_INCOMPATIBLE);
    });

    it('answers a version refusal with the versions it speaks', () => {
        // The whole point of the code: the client cannot negotiate without them.
        const error = parseEnvelope(body({v: PROTOCOL_V_MAX + 1})).error;
        assert.deepEqual(
            [error.v, error.vMin, error.vMax],
            [PROTOCOL_V, PROTOCOL_V_MIN, PROTOCOL_V_MAX]
        );
    });

    it('checks the version before anything else', () => {
        // Without agreement on the contract there is nothing to interpret, so a
        // body that is wrong in several ways at once is answered about its
        // version and not about its token.
        assertRejected(
            parseEnvelope({v: PROTOCOL_V_MAX + 1, action: 'nonsense'}),
            ERROR.PROTOCOL_INCOMPATIBLE
        );
    });
});

describe('parseEnvelope: token', () => {
    for (const bad of [undefined, '', 42, null, {}]) {
        it('refuses a token of ' + label(bad), () => {
            assertRejected(parseEnvelope(body({token: bad})), ERROR.UNAUTHORIZED, /Missing token/);
        });
    }

    it('accepts a token of nothing but spaces', () => {
        // Only the exactly empty string is caught here, so `authenticate` is what
        // has to refuse a blank secret. Pinned because the two guards are in
        // different files and it would be easy to assume this one covers more
        // than it does.
        assert.equal(accepted(parseEnvelope(body({token: '   '}))).token, '   ');
    });

    it('refuses a missing token before an unknown action', () => {
        // Deliberate: what actions exist is not something to tell a caller who
        // has not shown a token.
        assertRejected(
            parseEnvelope(bodyWithout('token')),
            ERROR.UNAUTHORIZED
        );
        assertRejected(
            parseEnvelope(Object.assign(bodyWithout('token'), {action: 'flight-log/list'})),
            ERROR.UNAUTHORIZED
        );
    });
});

describe('parseEnvelope: action', () => {
    for (const action of KNOWN_ACTIONS) {
        it('accepts ' + action, () => {
            assert.equal(accepted(parseEnvelope(body({action: action}))).action, action);
        });
    }

    for (const bad of [undefined, '', 'flight-log/list', 'FLIGHT-LOG/INSERT', 7, null]) {
        it('refuses an action of ' + label(bad), () => {
            assertRejected(parseEnvelope(body({action: bad})), ERROR.BAD_REQUEST, /Unknown action/);
        });
    }

    it('requires every known action to be a mutating one', () => {
        // True today, and the reason `requestId` is unconditionally required
        // below. The day a read-only action appears, this test is where someone
        // has to decide what that means for idempotency.
        assert.deepEqual(KNOWN_ACTIONS.filter(function (a) { return !isMutating(a); }), []);
    });

    it('reports an unknown action as not mutating', () => {
        assert.equal(isMutating('flight-log/list'), false);
        assert.equal(isMutating(undefined), false);
    });
});

describe('parseEnvelope: requestId', () => {
    for (const action of KNOWN_ACTIONS) {
        it('requires one for ' + action, () => {
            assertRejected(
                parseEnvelope(Object.assign(bodyWithout('requestId'), {action: action})),
                ERROR.BAD_REQUEST,
                /Missing "requestId"/
            );
        });
    }

    for (const bad of ['', 42, null, {}]) {
        it('treats a requestId of ' + label(bad) + ' as absent', () => {
            assertRejected(parseEnvelope(body({requestId: bad})), ERROR.BAD_REQUEST, /Missing "requestId"/);
        });
    }

    it('keeps a usable one', () => {
        assert.equal(accepted(parseEnvelope(body({requestId: 'abc'}))).requestId, 'abc');
    });
});

describe('parseEnvelope: normalization', () => {
    it('defaults the optional fields', () => {
        const envelope = accepted(parseEnvelope(body()));
        assert.deepEqual(
            [envelope.expect, envelope.payload, envelope.client, envelope.force],
            [null, {}, null, false]
        );
    });

    it('keeps what it was given', () => {
        const envelope = accepted(parseEnvelope(body({
            expect: {version: 3},
            payload: {id: 'x'},
            client: 'airborne/1.2.3',
            force: true
        })));
        assert.deepEqual(envelope.expect, {version: 3});
        assert.deepEqual(envelope.payload, {id: 'x'});
        assert.equal(envelope.client, 'airborne/1.2.3');
        assert.equal(envelope.force, true);
    });

    for (const bad of ['yes', 7, true, null]) {
        it('nulls an expect of ' + label(bad), () => {
            assert.equal(accepted(parseEnvelope(body({expect: bad}))).expect, null);
        });
    }

    for (const bad of ['{}', 7, true, null]) {
        it('empties a payload of ' + label(bad), () => {
            assert.deepEqual(accepted(parseEnvelope(body({payload: bad}))).payload, {});
        });
    }

    it('nulls a non-string client', () => {
        assert.equal(accepted(parseEnvelope(body({client: {name: 'airborne'}}))).client, null);
    });

    for (const notTrue of ['true', 1, 'yes', {}]) {
        it('reads a force of ' + label(notTrue) + ' as false', () => {
            // Strictly `=== true`: a flag that overrides a safety check should
            // take a boolean and nothing that merely looks like one.
            assert.equal(accepted(parseEnvelope(body({force: notTrue}))).force, false);
        });
    }

    it('lets an array through as a payload', () => {
        // `typeof [] === 'object'`, so it is kept. Harmless today — the schema
        // walk looks up field names and finds none on an array, so the row comes
        // out empty and required fields refuse it — but it is not a shape the
        // client ever sends.
        assert.ok(Array.isArray(accepted(parseEnvelope(body({payload: ['x']}))).payload));
    });

    it('carries nothing across that was not asked for', () => {
        const envelope = accepted(parseEnvelope(body({secret: 'do not copy me'})));
        assert.deepEqual(
            Object.keys(envelope).sort(),
            ['action', 'client', 'expect', 'force', 'payload', 'requestId', 'token', 'v']
        );
    });
});
