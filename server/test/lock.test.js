'use strict';

const test = require('node:test');
const assert = require('node:assert');
const {loadContext} = require('./helpers');
const {fakeSpreadsheetApp, fakeLockService, fakeCacheService} = require('./fake-apps-script');

function makeCtx(lockOpts) {
    const {SpreadsheetApp, state: spreadsheetState} = fakeSpreadsheetApp({});
    const {LockService, state: lockState} = fakeLockService(lockOpts);
    const {CacheService, store: cacheStore} = fakeCacheService();
    const ctx = loadContext(['00_config.js', '10_protocol.js', '40_store.js', '50_lock.js'], {SpreadsheetApp, LockService, CacheService});
    return {ctx, spreadsheetState, lockState, cacheStore};
}

// --- withLock --------------------------------------------------------------

test('withLock runs fn while holding the lock, then flushes and releases', () => {
    const {ctx, spreadsheetState, lockState} = makeCtx();
    let called = false;
    const result = ctx.withLock(() => {
        called = true;
        return {ok: true, data: 'x'};
    });
    assert.strictEqual(called, true);
    assert.deepEqual(result, {ok: true, data: 'x'});
    assert.strictEqual(lockState.releaseLockCalls, 1);
    assert.strictEqual(spreadsheetState.flushCalls, 1);
});

test('withLock returns BUSY without calling fn when the lock cannot be acquired', () => {
    const {ctx, spreadsheetState, lockState} = makeCtx({failToLock: true});
    let called = false;
    const result = ctx.withLock(() => {
        called = true;
    });
    assert.strictEqual(called, false);
    assert.strictEqual(result.error.code, ctx.ERROR.BUSY);
    assert.strictEqual(lockState.releaseLockCalls, 0);
    assert.strictEqual(spreadsheetState.flushCalls, 0);
});

test('withLock still flushes and releases the lock when fn throws', () => {
    const {ctx, spreadsheetState, lockState} = makeCtx();
    assert.throws(() => {
        ctx.withLock(() => {
            throw new Error('boom');
        });
    }, /boom/);
    assert.strictEqual(lockState.releaseLockCalls, 1);
    assert.strictEqual(spreadsheetState.flushCalls, 1);
});

// --- withIdempotency ---------------------------------------------------------

test('withIdempotency runs fn directly when there is no requestId', () => {
    const {ctx, cacheStore} = makeCtx();
    let calls = 0;
    const result = ctx.withIdempotency(null, () => {
        calls++;
        return {ok: true};
    });
    assert.strictEqual(calls, 1);
    assert.deepEqual(result, {ok: true});
    assert.strictEqual(cacheStore.size, 0);
});

test('withIdempotency replays a cached successful response instead of calling fn again', () => {
    const {ctx} = makeCtx();
    let calls = 0;
    const fn = () => {
        calls++;
        return {ok: true, data: calls};
    };

    const first = ctx.withIdempotency('req-1', fn);
    assert.strictEqual(first.data, 1);
    assert.strictEqual('replayed' in first, false);

    const second = ctx.withIdempotency('req-1', fn);
    assert.strictEqual(calls, 1, 'fn must not run again on replay');
    assert.strictEqual(second.data, 1);
    assert.strictEqual(second.replayed, true);
});

test('withIdempotency does not cache a non-ok response, so a retry re-runs fn', () => {
    const {ctx} = makeCtx();
    let calls = 0;
    const fn = () => {
        calls++;
        return {ok: false, error: {code: 'CONFLICT'}};
    };

    ctx.withIdempotency('req-2', fn);
    ctx.withIdempotency('req-2', fn);
    assert.strictEqual(calls, 2);
});

test('withIdempotency discards a corrupted cache entry and re-runs fn', () => {
    const {ctx, cacheStore} = makeCtx();
    cacheStore.set('req:req-3', 'not valid json{{');

    let calls = 0;
    const result = ctx.withIdempotency('req-3', () => {
        calls++;
        return {ok: true, data: 'fresh'};
    });
    assert.strictEqual(calls, 1);
    assert.strictEqual(result.data, 'fresh');
    // The corrupted entry is overwritten with a valid one on the way out.
    assert.deepEqual(JSON.parse(cacheStore.get('req:req-3')), {ok: true, data: 'fresh'});
});
