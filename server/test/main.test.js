'use strict';

/** Full-stack tests for 90_main.js: doGet/doPost/handleRequest/dispatch. */

const test = require('node:test');
const assert = require('node:assert');
const {loadContext} = require('./helpers');
const {
    FakeSheet,
    fakeSpreadsheetApp,
    fakeProperties,
    fakeContentService,
    fakeLockService,
    fakeCacheService
} = require('./fake-apps-script');

const HEADER = ['createdAt', 'date', 'pilotName', 'startHour', 'endHour', 'origin', 'destination', 'fuel', 'fuelPrice', 'notes', 'flightTime', 'stableId'];

function makeCtx({properties, lockOpts} = {}) {
    const flightLogSheet = new FakeSheet('Registro voli', [HEADER]);
    const metadataSheet = new FakeSheet('Metadata', [['key', 'value'], ['token.mario', 'secret-token']]);
    const {SpreadsheetApp, state: spreadsheetState} = fakeSpreadsheetApp({
        'Registro voli': flightLogSheet,
        Metadata: metadataSheet
    });
    const {LockService, state: lockState} = fakeLockService(lockOpts);
    const {CacheService} = fakeCacheService();

    const ctx = loadContext(
        ['00_config.js', '10_protocol.js', '20_auth.js', '40_store.js', '50_lock.js', '60_actions.js', '90_main.js'],
        Object.assign(
            {SpreadsheetApp, LockService, CacheService},
            fakeContentService(),
            fakeProperties(Object.assign({METADATA_SHEET_NAME: 'Metadata', FLIGHT_LOG_SHEET_NAME: 'Registro voli'}, properties))
        )
    );
    return {ctx, flightLogSheet, metadataSheet, spreadsheetState, lockState};
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

test('doPost rejects an unknown token as UNAUTHORIZED', () => {
    const {ctx} = makeCtx();
    const parsed = JSON.parse(ctx.doPost(e(validBody({token: 'wrong'}))).getContent());
    assert.strictEqual(parsed.error.code, ctx.ERROR.UNAUTHORIZED);
});

// --- doPost: the happy path, end to end ---------------------------------------

test('doPost runs a mutating action end to end and mutates the sheet', () => {
    const {ctx, flightLogSheet} = makeCtx();
    const parsed = JSON.parse(ctx.doPost(e(validBody())).getContent());

    assert.strictEqual(parsed.ok, true);
    assert.match(parsed.data.id, /^[a-z][a-z0-9]{9}$/);
    assert.strictEqual(flightLogSheet.data.length, 2);
});

test('doPost returns BUSY without mutating the sheet when the lock is held elsewhere', () => {
    const {ctx, flightLogSheet} = makeCtx({lockOpts: {failToLock: true}});
    const parsed = JSON.parse(ctx.doPost(e(validBody())).getContent());

    assert.strictEqual(parsed.error.code, ctx.ERROR.BUSY);
    assert.strictEqual(flightLogSheet.data.length, 1);
});

test('doPost replays the cached response for a repeated requestId instead of inserting twice', () => {
    const {ctx, flightLogSheet} = makeCtx();
    const body = validBody();

    const first = JSON.parse(ctx.doPost(e(body)).getContent());
    const second = JSON.parse(ctx.doPost(e(body)).getContent());

    assert.strictEqual('replayed' in first, false);
    assert.strictEqual(second.replayed, true);
    assert.strictEqual(second.data.id, first.data.id);
    assert.strictEqual(flightLogSheet.data.length, 2, 'the second call must not append a second row');
});

// --- doPost: unexpected failures --------------------------------------------

test('doPost turns an unexpected exception into an INTERNAL response and still releases the lock', () => {
    // No FLIGHT_LOG_SHEET_NAME configured: openFlightLogSheet throws deep inside the locked section.
    const {ctx, lockState} = makeCtx({properties: {FLIGHT_LOG_SHEET_NAME: null}});
    const parsed = JSON.parse(ctx.doPost(e(validBody())).getContent());

    assert.strictEqual(parsed.error.code, ctx.ERROR.INTERNAL);
    assert.match(parsed.error.message, /FLIGHT_LOG_SHEET_NAME/);
    assert.strictEqual(lockState.releaseLockCalls, 1);
});

// --- dispatch ------------------------------------------------------------------

test('dispatch reports an unhandled action as BAD_REQUEST', () => {
    const {ctx} = makeCtx();
    const response = ctx.dispatch({action: 'bogus', payload: {}}, {pilotName: 'mario', role: 'pilot'});
    assert.strictEqual(response.error.code, ctx.ERROR.BAD_REQUEST);
});
