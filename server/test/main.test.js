'use strict';

/**
 * Full-stack tests for 90_main.js: doGet/doPost/handleRequest/dispatch.
 *
 * The store (40_store.js) is fully mocked here: this file's job is protocol
 * routing (envelope parsing, auth, lock, idempotency, error mapping), not
 * spreadsheet semantics — those are covered by store.test.js and
 * actions-flightlog.test.js. No FakeSheet involved.
 */

const test = require('node:test');
const assert = require('node:assert');
const {loadContext} = require('./helpers');
const {mockStore} = require('./mock-store');
const {
    fakeProperties,
    fakeContentService,
    fakeLockService,
    fakeCacheService
} = require('./fake-apps-script');

function makeCtx({storeImpls, properties, lockOpts} = {}) {
    const store = mockStore(Object.assign({readMetadata: () => ({'token.mario': 'secret-token'})}, storeImpls));
    const {LockService, state: lockState} = fakeLockService(lockOpts);
    const {CacheService} = fakeCacheService();

    const ctx = loadContext(
        ['00_config.js', '10_protocol.js', '20_auth.js', '50_lock.js', '60_actions.js', '90_main.js'],
        Object.assign(
            {LockService, CacheService},
            store,
            fakeContentService(),
            fakeProperties(properties)
        )
    );
    return {ctx, store, lockState};
}

function e(bodyObj) {
    return {postData: {contents: JSON.stringify(bodyObj)}};
}

function validBody(overrides) {
    return Object.assign(
        {
            v: 1,
            token: 'secret-token',
            action: 'flight-log/insert',
            requestId: 'req-1',
            payload: {date: '2024-03-05', startHour: 1, endHour: 2, origin: 'LIML', destination: 'LIME'}
        },
        overrides
    );
}

// --- doGet -----------------------------------------------------------------

test('doGet reports the service, build id and supported protocol range', () => {
    const {ctx} = makeCtx();
    const parsed = JSON.parse(ctx.doGet().getContent());
    assert.strictEqual(parsed.ok, true);
    assert.strictEqual(parsed.v, ctx.PROTOCOL_V);
    assert.strictEqual(parsed.vMin, ctx.PROTOCOL_V_MIN);
    assert.strictEqual(parsed.vMax, ctx.PROTOCOL_V_MAX);
    assert.strictEqual(parsed.data.service, 'airborne');
    assert.strictEqual(parsed.data.buildId, 'dev');
});

// --- doPost: malformed requests -----------------------------------------------

test('doPost rejects a request with no body as BAD_REQUEST', () => {
    const {ctx} = makeCtx();
    for (const bad of [undefined, {}, {postData: {}}, {postData: {contents: ''}}]) {
        const parsed = JSON.parse(ctx.doPost(bad).getContent());
        assert.strictEqual(parsed.error.code, ctx.ERROR.BAD_REQUEST, JSON.stringify(bad));
    }
});

test('doPost rejects a body that is not valid JSON', () => {
    const {ctx} = makeCtx();
    const parsed = JSON.parse(ctx.doPost({postData: {contents: 'not json'}}).getContent());
    assert.strictEqual(parsed.error.code, ctx.ERROR.BAD_REQUEST);
});

test('doPost rejects an unknown token as UNAUTHORIZED, without touching the store', () => {
    const {ctx, store} = makeCtx();
    const parsed = JSON.parse(ctx.doPost(e(validBody({token: 'wrong'}))).getContent());
    assert.strictEqual(parsed.error.code, ctx.ERROR.UNAUTHORIZED);
    assert.strictEqual(store.openFlightLogSheet.mock.calls.length, 0);
});

// --- doPost: the happy path, end to end ---------------------------------------

test('doPost runs a mutating action end to end, driving the store through the expected calls', () => {
    const {ctx, store} = makeCtx();
    const parsed = JSON.parse(ctx.doPost(e(validBody())).getContent());

    assert.strictEqual(parsed.ok, true);
    assert.match(parsed.data.id, /^[a-z][a-z0-9]{9}$/);
    assert.strictEqual(store.appendRow.mock.calls.length, 1);
    assert.strictEqual(store.sortSheet.mock.calls.length, 1);
    assert.deepEqual(store.updateVersionMetadata.mock.calls[0].arguments, [ctx.FLIGHT_LOG_VERSION_KEY]);
});

test('doPost returns BUSY without touching the store when the lock is held elsewhere', () => {
    const {ctx, store} = makeCtx({lockOpts: {failToLock: true}});
    const parsed = JSON.parse(ctx.doPost(e(validBody())).getContent());

    assert.strictEqual(parsed.error.code, ctx.ERROR.BUSY);
    assert.strictEqual(store.appendRow.mock.calls.length, 0);
});

test('doPost replays the cached response for a repeated requestId instead of inserting twice', () => {
    const {ctx, store} = makeCtx();
    const body = validBody();

    const first = JSON.parse(ctx.doPost(e(body)).getContent());
    const second = JSON.parse(ctx.doPost(e(body)).getContent());

    assert.strictEqual('replayed' in first, false);
    assert.strictEqual(second.replayed, true);
    assert.strictEqual(second.data.id, first.data.id);
    assert.strictEqual(store.appendRow.mock.calls.length, 1, 'the second call must not insert a second time');
});

// --- doPost: unexpected failures --------------------------------------------

test('doPost turns an unexpected exception into an INTERNAL response and still releases the lock', () => {
    const {ctx, lockState} = makeCtx({
        storeImpls: {
            openFlightLogSheet: () => {
                throw new Error('boom');
            }
        }
    });
    const parsed = JSON.parse(ctx.doPost(e(validBody())).getContent());

    assert.strictEqual(parsed.error.code, ctx.ERROR.INTERNAL);
    assert.match(parsed.error.message, /boom/);
    assert.strictEqual(lockState.releaseLockCalls, 1);
});

// --- dispatch ------------------------------------------------------------------

test('dispatch reports an unhandled action as BAD_REQUEST', () => {
    const {ctx} = makeCtx();
    const response = ctx.dispatch({action: 'bogus', payload: {}}, {pilotName: 'mario', role: 'pilot'});
    assert.strictEqual(response.error.code, ctx.ERROR.BAD_REQUEST);
});
