/**
 * Response shapes.
 *
 * `ContentService` cannot set an HTTP status, so every answer leaves with 200
 * and the outcome lives in the body: `ok`, and a machine-readable `code` when it
 * is false. That makes the shape of these two objects the entire contract — a
 * client cannot fall back on the status line if a field goes missing.
 *
 * Two consequences drive what is tested here. The body is what the app switches
 * on, so `ok` and `code` must be present and unambiguous on every path. And the
 * body is what `withIdempotency` stores as JSON and replays later, so a response
 * has to survive a round trip through `JSON.stringify` unchanged.
 */

const {describe, it} = require('node:test');
const assert = require('node:assert/strict');

require('./load.js');
require('./stubs.js');

const VERSIONS = [PROTOCOL_V, PROTOCOL_V_MIN, PROTOCOL_V_MAX];

function versionsOf(response) {
    return [response.v, response.vMin, response.vMax];
}

describe('okResponse', () => {
    it('announces success and the versions it speaks', () => {
        const response = okResponse({id: 'abc'});
        assert.equal(response.ok, true);
        assert.deepEqual(versionsOf(response), VERSIONS);
    });

    it('carries the data it was given', () => {
        assert.deepEqual(okResponse({id: 'abc'}).data, {id: 'abc'});
    });

    it('reports no data as null', () => {
        assert.equal(okResponse().data, null);
        assert.equal(okResponse(undefined).data, null);
        assert.equal(okResponse(null).data, null);
    });

    for (const falsy of [0, false, '']) {
        it('keeps a falsy datum of ' + JSON.stringify(falsy), () => {
            // The check is `=== undefined`, not a truthiness test. It has to be:
            // a count of zero is an answer, and turning it into null would make
            // the client read "no data" where the server said "none of them".
            assert.equal(okResponse(falsy).data, falsy);
        });
    }

    it('carries no error field', () => {
        assert.deepEqual(Object.keys(okResponse('x')).sort(), ['data', 'ok', 'v', 'vMax', 'vMin']);
    });
});

describe('errorResponse', () => {
    it('announces failure and the versions it speaks', () => {
        const response = errorResponse(ERROR.BUSY, 'try later');
        assert.equal(response.ok, false);
        assert.deepEqual(versionsOf(response), VERSIONS);
    });

    it('carries the code and the message', () => {
        const response = errorResponse(ERROR.FORBIDDEN, 'not yours');
        assert.equal(response.error.code, ERROR.FORBIDDEN);
        assert.equal(response.error.message, 'not yours');
    });

    it('falls back to the code as its own message', () => {
        // Clients localize from the code and show the message only for codes they
        // do not know, so the fallback still has to say something.
        assert.equal(errorResponse(ERROR.INTERNAL).error.message, ERROR.INTERNAL);
        assert.equal(errorResponse(ERROR.INTERNAL, '').error.message, ERROR.INTERNAL);
    });

    it('omits details rather than sending them undefined', () => {
        // An absent key and a key holding undefined serialize the same, but only
        // after JSON.stringify; anything reading the object before that sees the
        // difference.
        assert.equal('details' in errorResponse(ERROR.BUSY, 'x').error, false);
        assert.equal('details' in errorResponse(ERROR.BUSY, 'x', null).error, false);
        assert.equal('details' in errorResponse(ERROR.BUSY, 'x', '').error, false);
    });

    it('carries details when there are any', () => {
        assert.deepEqual(errorResponse(ERROR.BAD_REQUEST, 'x', {field: 'date'}).error.details, {field: 'date'});
    });

    it('carries no data field', () => {
        assert.deepEqual(
            Object.keys(errorResponse(ERROR.BUSY, 'x')).sort(),
            ['error', 'ok', 'v', 'vMax', 'vMin']
        );
    });
});

describe('entryNotFoundErrorResponse', () => {
    it('answers NOT_FOUND, naming the entry', () => {
        const response = entryNotFoundErrorResponse('ab12cd34ef');
        assert.equal(response.ok, false);
        assert.equal(response.error.code, ERROR.NOT_FOUND);
        assert.match(response.error.message, /ab12cd34ef/);
    });

    it('echoes the id exactly as it was asked for', () => {
        // The id comes from the payload, so the message reflects caller text
        // back. Harmless for a JSON body a Flutter app parses, but pinned so that
        // nobody later renders one of these messages as markup without noticing.
        assert.match(entryNotFoundErrorResponse('<b>').error.message, /<b>/);
    });
});

describe('the error codes', () => {
    it('names every code after itself', () => {
        // A client switches on these strings. A key and a value that drift apart
        // is a bug that only shows up in the field, on the one branch nobody
        // exercised.
        for (const name of Object.keys(ERROR)) {
            assert.equal(ERROR[name], name);
        }
    });

    it('covers every code the sources actually use', () => {
        assert.deepEqual(Object.keys(ERROR).sort(), [
            'BAD_REQUEST', 'BUSY', 'FORBIDDEN', 'INTERNAL',
            'NOT_FOUND', 'PROTOCOL_INCOMPATIBLE', 'UNAUTHORIZED'
        ]);
    });
});

describe('serialization', () => {
    const responses = [
        okResponse(),
        okResponse({id: 'abc'}),
        okResponse(0),
        errorResponse(ERROR.BUSY),
        errorResponse(ERROR.BAD_REQUEST, 'bad', {field: 'date'})
    ];

    for (const response of responses) {
        it('survives a JSON round trip: ' + JSON.stringify(response.ok ? response.data : response.error.code), () => {
            // `withIdempotency` stores the response as text and replays the parsed
            // copy, so anything that does not survive this would come back
            // different on a retry than it went out the first time.
            assert.deepEqual(JSON.parse(JSON.stringify(response)), response);
        });
    }

    it('never sends undefined where a client expects a field', () => {
        for (const response of responses) {
            for (const key of Object.keys(response)) {
                assert.notEqual(response[key], undefined, key + ' is undefined');
            }
        }
    });
});

describe('output', () => {
    it('serializes the response as JSON text', () => {
        const response = okResponse({id: 'abc'});
        assert.deepEqual(JSON.parse(output(response).getContent()), response);
    });

    it('declares the JSON mime type', () => {
        assert.equal(output(okResponse()).getMimeType(), ContentService.MimeType.JSON);
    });

    it('serializes a refusal the same way', () => {
        const response = errorResponse(ERROR.UNAUTHORIZED, 'Unknown or revoked token');
        assert.deepEqual(JSON.parse(output(response).getContent()), response);
    });
});