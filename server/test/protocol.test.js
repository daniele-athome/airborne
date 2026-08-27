'use strict';

const test = require('node:test');
const assert = require('node:assert');
const {loadContext} = require('./helpers');
const {fakeContentService} = require('./fake-apps-script');

function makeCtx() {
    return loadContext(['00_config.js', '10_protocol.js'], fakeContentService());
}

function envelope(overrides) {
    return Object.assign(
        {
            v: 1,
            token: 'a-token',
            action: 'flight-log/insert',
            requestId: 'req-1'
        },
        overrides
    );
}

test('a well formed envelope is accepted and normalized', () => {
    const ctx = makeCtx();
    const parsed = ctx.parseEnvelope(envelope());
    assert.ok(!parsed.error);
    assert.strictEqual(parsed.envelope.action, 'flight-log/insert');
    assert.strictEqual(parsed.envelope.requestId, 'req-1');
    assert.strictEqual(parsed.envelope.expect, null);
    assert.strictEqual(Object.keys(parsed.envelope.payload).length, 0);
    assert.strictEqual(parsed.envelope.client, null);
    assert.strictEqual(parsed.envelope.force, false);
});

test('body must be a JSON object', () => {
    const ctx = makeCtx();
    assert.strictEqual(ctx.parseEnvelope(null).error.error.code, ctx.ERROR.BAD_REQUEST);
    assert.strictEqual(ctx.parseEnvelope('nope').error.error.code, ctx.ERROR.BAD_REQUEST);
    assert.strictEqual(ctx.parseEnvelope(undefined).error.error.code, ctx.ERROR.BAD_REQUEST);
});

test('v is checked before anything else', () => {
    const ctx = makeCtx();
    assert.strictEqual(ctx.parseEnvelope(envelope({v: undefined})).error.error.code, ctx.ERROR.BAD_REQUEST);
    assert.strictEqual(ctx.parseEnvelope(envelope({v: 1.5})).error.error.code, ctx.ERROR.BAD_REQUEST);
    assert.strictEqual(ctx.parseEnvelope(envelope({v: '1'})).error.error.code, ctx.ERROR.BAD_REQUEST);

    // Even with a bogus token and action, an out-of-range v wins.
    const tooOld = ctx.parseEnvelope({v: ctx.PROTOCOL_V_MIN - 1, token: '', action: 'nope'});
    assert.strictEqual(tooOld.error.error.code, ctx.ERROR.PROTOCOL_INCOMPATIBLE);
});

test('a protocol version below the supported range is rejected', () => {
    const ctx = makeCtx();
    const parsed = ctx.parseEnvelope(envelope({v: ctx.PROTOCOL_V_MIN - 1}));
    assert.strictEqual(parsed.error.error.code, ctx.ERROR.PROTOCOL_INCOMPATIBLE);
});

test('a protocol version above the supported range is rejected', () => {
    const ctx = makeCtx();
    const parsed = ctx.parseEnvelope(envelope({v: ctx.PROTOCOL_V_MAX + 1}));
    assert.strictEqual(parsed.error.error.code, ctx.ERROR.PROTOCOL_INCOMPATIBLE);
});

test('a missing or empty token is unauthorized, not a bad request', () => {
    const ctx = makeCtx();
    assert.strictEqual(ctx.parseEnvelope(envelope({token: undefined})).error.error.code, ctx.ERROR.UNAUTHORIZED);
    assert.strictEqual(ctx.parseEnvelope(envelope({token: ''})).error.error.code, ctx.ERROR.UNAUTHORIZED);
    assert.strictEqual(ctx.parseEnvelope(envelope({token: 42})).error.error.code, ctx.ERROR.UNAUTHORIZED);
});

test('an unknown action is a bad request', () => {
    const ctx = makeCtx();
    assert.strictEqual(ctx.parseEnvelope(envelope({action: 'flight-log/truncate'})).error.error.code, ctx.ERROR.BAD_REQUEST);
    assert.strictEqual(ctx.parseEnvelope(envelope({action: undefined})).error.error.code, ctx.ERROR.BAD_REQUEST);
});

test('every known action is mutating and requires a requestId', () => {
    const ctx = makeCtx();
    for (const action of ctx.KNOWN_ACTIONS) {
        assert.strictEqual(ctx.isMutating(action), true, action + ' should be mutating');
        const withoutId = ctx.parseEnvelope(envelope({action, requestId: undefined}));
        assert.strictEqual(withoutId.error.error.code, ctx.ERROR.BAD_REQUEST, action + ' without requestId');
        const withId = ctx.parseEnvelope(envelope({action, requestId: 'uuid-1'}));
        assert.ok(!withId.error, action + ' with requestId');
    }
});

test('an empty requestId string counts as missing', () => {
    const ctx = makeCtx();
    const parsed = ctx.parseEnvelope(envelope({requestId: ''}));
    assert.strictEqual(parsed.error.error.code, ctx.ERROR.BAD_REQUEST);
});

test('force defaults to false and is only honoured when strictly true', () => {
    const ctx = makeCtx();
    assert.strictEqual(ctx.parseEnvelope(envelope()).envelope.force, false);
    assert.strictEqual(ctx.parseEnvelope(envelope({force: 'yes'})).envelope.force, false);
    assert.strictEqual(ctx.parseEnvelope(envelope({force: 1})).envelope.force, false);
    assert.strictEqual(ctx.parseEnvelope(envelope({force: true})).envelope.force, true);
});

test('non-object expect/payload and non-string client are ignored rather than rejected', () => {
    const ctx = makeCtx();
    const parsed = ctx.parseEnvelope(envelope({expect: 'nope', payload: 'nope', client: 42}));
    assert.ok(!parsed.error);
    assert.strictEqual(parsed.envelope.expect, null);
    // The {} fallback is built inside the sandbox, so it is a different realm's object.
    assert.deepEqual(parsed.envelope.payload, {});
    assert.strictEqual(parsed.envelope.client, null);
});

test('a well formed expect/payload/client pass through', () => {
    const ctx = makeCtx();
    const parsed = ctx.parseEnvelope(envelope({expect: {fingerprint: 'a'}, payload: {id: '1'}, client: 'app/1.0'}));
    assert.deepStrictEqual(parsed.envelope.expect, {fingerprint: 'a'});
    assert.deepStrictEqual(parsed.envelope.payload, {id: '1'});
    assert.strictEqual(parsed.envelope.client, 'app/1.0');
});

test('okResponse carries the protocol range and defaults data to null', () => {
    const ctx = makeCtx();
    const withData = ctx.okResponse({a: 1});
    assert.strictEqual(withData.ok, true);
    assert.strictEqual(withData.v, ctx.PROTOCOL_V);
    assert.strictEqual(withData.vMin, ctx.PROTOCOL_V_MIN);
    assert.strictEqual(withData.vMax, ctx.PROTOCOL_V_MAX);
    assert.deepStrictEqual(withData.data, {a: 1});

    assert.strictEqual(ctx.okResponse(undefined).data, null);
});

test('errorResponse defaults message to the code and omits details when falsy', () => {
    const ctx = makeCtx();
    const bare = ctx.errorResponse(ctx.ERROR.INTERNAL);
    assert.strictEqual(bare.ok, false);
    assert.strictEqual(bare.error.code, ctx.ERROR.INTERNAL);
    assert.strictEqual(bare.error.message, ctx.ERROR.INTERNAL);
    assert.strictEqual('details' in bare.error, false);

    const withDetails = ctx.errorResponse(ctx.ERROR.BAD_REQUEST, 'oops', {field: 'x'});
    assert.strictEqual(withDetails.error.message, 'oops');
    assert.deepStrictEqual(withDetails.error.details, {field: 'x'});
});

test('entryNotFoundErrorResponse reports NOT_FOUND with the id in the message', () => {
    const ctx = makeCtx();
    const response = ctx.entryNotFoundErrorResponse('abc123');
    assert.strictEqual(response.error.code, ctx.ERROR.NOT_FOUND);
    assert.match(response.error.message, /abc123/);
});

test('output wraps the response as JSON text content', () => {
    const ctx = makeCtx();
    const response = ctx.okResponse({a: 1});
    const out = ctx.output(response);
    assert.strictEqual(out.getMimeType(), 'JSON');
    // response was built inside the sandbox; JSON.parse always returns main-realm objects.
    assert.deepEqual(JSON.parse(out.getContent()), response);
});
