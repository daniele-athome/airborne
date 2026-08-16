'use strict';

const test = require('node:test');
const assert = require('node:assert');
const { loadContext } = require('./helpers');

const ctx = loadContext(['00_config.js', '10_protocol.js']);

function envelope(overrides) {
  return Object.assign(
    {
      v: ctx.PROTOCOL_V,
      token: 'a-token',
      action: 'list',
      store: 'flight_log'
    },
    overrides
  );
}

test('a well formed envelope is accepted', () => {
  const parsed = ctx.parseEnvelope(envelope());
  assert.ok(!parsed.error);
  assert.strictEqual(parsed.envelope.action, 'list');
  // Objects come from the sandbox realm, so compare shape rather than identity.
  assert.strictEqual(Object.keys(parsed.envelope.payload).length, 0);
});

test('an older protocol version is rejected with a distinct code', () => {
  const parsed = ctx.parseEnvelope(envelope({ v: ctx.PROTOCOL_V_MIN - 1 }));
  assert.strictEqual(parsed.error.error.code, ctx.ERROR.PROTOCOL_TOO_OLD);
  assert.strictEqual(parsed.error.vMin, ctx.PROTOCOL_V_MIN);
});

test('a newer protocol version is rejected too', () => {
  // Happens after a deployment rollback, which is two clicks away.
  const parsed = ctx.parseEnvelope(envelope({ v: ctx.PROTOCOL_V_MAX + 1 }));
  assert.strictEqual(parsed.error.error.code, ctx.ERROR.PROTOCOL_TOO_NEW);
  assert.strictEqual(parsed.error.vMax, ctx.PROTOCOL_V_MAX);
});

test('the version is checked before anything else', () => {
  const parsed = ctx.parseEnvelope({ v: ctx.PROTOCOL_V_MAX + 1 });
  assert.strictEqual(parsed.error.error.code, ctx.ERROR.PROTOCOL_TOO_NEW);
});

test('a missing token is unauthorized, not a bad request', () => {
  const parsed = ctx.parseEnvelope(envelope({ token: undefined }));
  assert.strictEqual(parsed.error.error.code, ctx.ERROR.UNAUTHORIZED);
});

test('an unknown action is rejected', () => {
  const parsed = ctx.parseEnvelope(envelope({ action: 'truncate' }));
  assert.strictEqual(parsed.error.error.code, ctx.ERROR.BAD_REQUEST);
});

test('store is required except on bootstrap', () => {
  assert.strictEqual(
    ctx.parseEnvelope(envelope({ store: undefined })).error.error.code,
    ctx.ERROR.BAD_REQUEST
  );
  assert.ok(!ctx.parseEnvelope(envelope({ action: 'bootstrap', store: undefined })).error);
});

test('mutating actions require a requestId', () => {
  const withoutId = ctx.parseEnvelope(envelope({ action: 'insert' }));
  assert.strictEqual(withoutId.error.error.code, ctx.ERROR.BAD_REQUEST);

  const withId = ctx.parseEnvelope(envelope({ action: 'insert', requestId: 'uuid-1' }));
  assert.ok(!withId.error);
});

test('reads do not require a requestId', () => {
  assert.ok(!ctx.parseEnvelope(envelope({ action: 'list' })).error);
});

test('force defaults to false and is only honoured when strictly true', () => {
  assert.strictEqual(ctx.parseEnvelope(envelope()).envelope.force, false);
  assert.strictEqual(ctx.parseEnvelope(envelope({ force: 'yes' })).envelope.force, false);
  assert.strictEqual(ctx.parseEnvelope(envelope({ force: true })).envelope.force, true);
});

test('every response carries the supported version range', () => {
  const ok = ctx.okResponse({ a: 1 }, {});
  assert.strictEqual(ok.vMin, ctx.PROTOCOL_V_MIN);
  assert.strictEqual(ok.vMax, ctx.PROTOCOL_V_MAX);

  const err = ctx.errorResponse(ctx.ERROR.CONFLICT, 'nope');
  assert.strictEqual(err.ok, false);
  assert.strictEqual(err.vMax, ctx.PROTOCOL_V_MAX);
});

test('cursors round-trip and reject garbage', () => {
  const encoded = ctx.encodeCursor({ lastOrdinal: 42, hash: '7' });
  const decoded = ctx.decodeCursor(encoded);
  assert.strictEqual(decoded.lastOrdinal, 42);
  assert.strictEqual(decoded.hash, '7');
  assert.strictEqual(ctx.decodeCursor('not-base64-json'), null);
  assert.strictEqual(ctx.decodeCursor(''), null);
  assert.strictEqual(ctx.decodeCursor(undefined), null);
});
