'use strict';

/**
 * End-to-end tests for actionFlightLogInsert/Update/Delete against a fake
 * in-memory sheet: append/write/delete, re-sort, and the metadata version
 * bump, on top of the identity rules already covered in identity.test.js.
 */

const test = require('node:test');
const assert = require('node:assert');
const {loadContext} = require('./helpers');
const {FakeSheet, fakeSpreadsheetApp, fakeProperties} = require('./fake-apps-script');

// Mirrors flight_log_config.schema in src/60_actions.js: 12 columns, stable id
// in column 12 (index 11).
const FIELD = {
    createdAt: 0, date: 1, pilotName: 2, startHour: 3, endHour: 4,
    origin: 5, destination: 6, fuel: 7, fuelPrice: 8, notes: 9, flightTime: 10, stableId: 11
};
const HEADER = Object.keys(FIELD);

function row(fields) {
    const values = new Array(HEADER.length).fill('');
    for (const [name, value] of Object.entries(fields)) {
        values[FIELD[name]] = value;
    }
    return values;
}

function makeCtx({flightLogRows, metadataRows, properties} = {}) {
    const flightLogSheet = new FakeSheet('Registro voli', [HEADER, ...(flightLogRows || [])]);
    const metadataSheet = new FakeSheet('Metadata', [['key', 'value'], ...(metadataRows || [])]);
    const {SpreadsheetApp} = fakeSpreadsheetApp({'Registro voli': flightLogSheet, Metadata: metadataSheet});
    const ctx = loadContext(
        ['00_config.js', '10_protocol.js', '20_auth.js', '40_store.js', '60_actions.js'],
        Object.assign(
            {SpreadsheetApp},
            fakeProperties(Object.assign({METADATA_SHEET_NAME: 'Metadata', FLIGHT_LOG_SHEET_NAME: 'Registro voli'}, properties))
        )
    );
    return {ctx, flightLogSheet, metadataSheet};
}

const PILOT = {pilotName: 'mario', role: 'pilot'};
const ADMIN = {pilotName: 'admin-user', role: 'admin'};
const validPayload = () => ({date: '2024-03-05', startHour: 1, endHour: 2, origin: 'LIML', destination: 'LIME'});

// --- actionFlightLogInsert ----------------------------------------------------

test('insert: appends a row with the managed fields stamped, bumps the version counter', () => {
    const {ctx, flightLogSheet, metadataSheet} = makeCtx();
    const response = ctx.actionFlightLogInsert(validPayload(), PILOT);

    assert.strictEqual(response.ok, true);
    assert.match(response.data.id, /^[a-z][a-z0-9]{9}$/);
    assert.strictEqual(flightLogSheet.data.length, 2);

    const appended = flightLogSheet.data[1];
    assert.strictEqual(appended[FIELD.pilotName], 'mario');
    assert.strictEqual(appended[FIELD.origin], 'LIML');
    assert.strictEqual(appended[FIELD.stableId], response.data.id);
    assert.ok(appended[FIELD.createdAt] instanceof ctx.Date);
    assert.strictEqual(appended[FIELD.flightTime], null);

    assert.deepEqual(metadataSheet.data[1], [ctx.FLIGHT_LOG_VERSION_KEY, 1]);
});

test('insert: a pilot cannot file under another pilot\'s name, and the sheet is untouched', () => {
    const {ctx, flightLogSheet, metadataSheet} = makeCtx();
    const response = ctx.actionFlightLogInsert(Object.assign(validPayload(), {pilotName: 'luigi'}), PILOT);

    assert.strictEqual(response.error.code, ctx.ERROR.FORBIDDEN);
    assert.strictEqual(flightLogSheet.data.length, 1);
    assert.strictEqual(metadataSheet.data.length, 1);
});

test('insert: a missing required field is a bad request, and the sheet is untouched', () => {
    const {ctx, flightLogSheet} = makeCtx();
    const payload = validPayload();
    delete payload.date;
    const response = ctx.actionFlightLogInsert(payload, PILOT);

    assert.strictEqual(response.error.code, ctx.ERROR.BAD_REQUEST);
    assert.strictEqual(flightLogSheet.data.length, 1);
});

test('insert: an admin may file under an arbitrary name', () => {
    const {ctx, flightLogSheet} = makeCtx();
    const response = ctx.actionFlightLogInsert(Object.assign(validPayload(), {pilotName: 'luigi'}), ADMIN);

    assert.strictEqual(response.ok, true);
    assert.strictEqual(flightLogSheet.data[1][FIELD.pilotName], 'luigi');
});

test('insert: the sheet is re-sorted by startHour/endHour after every insert', () => {
    const {ctx, flightLogSheet} = makeCtx();
    ctx.actionFlightLogInsert(Object.assign(validPayload(), {startHour: 10, endHour: 11}), PILOT);
    ctx.actionFlightLogInsert(Object.assign(validPayload(), {startHour: 5, endHour: 6}), PILOT);

    assert.strictEqual(flightLogSheet.data[1][FIELD.startHour], 5);
    assert.strictEqual(flightLogSheet.data[2][FIELD.startHour], 10);
});

// --- actionFlightLogUpdate ----------------------------------------------------

test('update: a missing or empty id is a bad request', () => {
    const {ctx} = makeCtx();
    assert.strictEqual(ctx.actionFlightLogUpdate({}, PILOT).error.code, ctx.ERROR.BAD_REQUEST);
    assert.strictEqual(ctx.actionFlightLogUpdate({id: ''}, PILOT).error.code, ctx.ERROR.BAD_REQUEST);
});

test('update: an unknown id is not found', () => {
    const {ctx} = makeCtx();
    const response = ctx.actionFlightLogUpdate({id: 'nope'}, PILOT);
    assert.strictEqual(response.error.code, ctx.ERROR.NOT_FOUND);
});

test('update: a partial payload preserves everything else, resets flightTime, keeps immutable fields, and bumps the version', () => {
    const createdAt = new Date(2020, 0, 1);
    const {ctx, flightLogSheet, metadataSheet} = makeCtx({
        flightLogRows: [row({
            createdAt, date: new Date(2024, 0, 1), pilotName: 'mario',
            startHour: 1, endHour: 2, origin: 'LIML', destination: 'LIME',
            flightTime: 'stale', stableId: 'seed000001'
        })]
    });

    const response = ctx.actionFlightLogUpdate({id: 'seed000001', endHour: 9}, PILOT);

    assert.strictEqual(response.ok, true);
    assert.strictEqual(response.data.id, 'seed000001');
    const updated = flightLogSheet.data[1];
    assert.strictEqual(updated[FIELD.createdAt], createdAt);
    assert.strictEqual(updated[FIELD.stableId], 'seed000001');
    assert.strictEqual(updated[FIELD.startHour], 1);
    assert.strictEqual(updated[FIELD.endHour], 9);
    assert.strictEqual(updated[FIELD.origin], 'LIML');
    assert.strictEqual(updated[FIELD.flightTime], null);
    assert.deepEqual(metadataSheet.data[1], [ctx.FLIGHT_LOG_VERSION_KEY, 1]);
});

test('update: a pilot cannot modify another pilot\'s entry, and the row is untouched', () => {
    const {ctx, flightLogSheet} = makeCtx({
        flightLogRows: [row({pilotName: 'luigi', startHour: 1, endHour: 2, stableId: 'seed000001'})]
    });
    const response = ctx.actionFlightLogUpdate({id: 'seed000001', endHour: 9}, PILOT);

    assert.strictEqual(response.error.code, ctx.ERROR.FORBIDDEN);
    assert.strictEqual(flightLogSheet.data[1][FIELD.endHour], 2);
});

test('update: the owner may hand the entry over to the configured maintenance name', () => {
    const {ctx, flightLogSheet} = makeCtx({
        flightLogRows: [row({pilotName: 'mario', startHour: 1, endHour: 2, stableId: 'seed000001'})],
        properties: {NO_PILOT_NAME: 'manutenzione'}
    });
    const response = ctx.actionFlightLogUpdate({id: 'seed000001', pilotName: 'manutenzione'}, PILOT);

    assert.strictEqual(response.ok, true);
    assert.strictEqual(flightLogSheet.data[1][FIELD.pilotName], 'manutenzione');
});

// --- actionFlightLogDelete ----------------------------------------------------

test('delete: a missing or empty id is a bad request', () => {
    const {ctx} = makeCtx();
    assert.strictEqual(ctx.actionFlightLogDelete({}, PILOT).error.code, ctx.ERROR.BAD_REQUEST);
});

test('delete: an unknown id is not found', () => {
    const {ctx} = makeCtx();
    assert.strictEqual(ctx.actionFlightLogDelete({id: 'nope'}, PILOT).error.code, ctx.ERROR.NOT_FOUND);
});

test('delete: the owner may delete their own entry, which is removed and bumps the version', () => {
    const {ctx, flightLogSheet, metadataSheet} = makeCtx({
        flightLogRows: [row({pilotName: 'mario', startHour: 1, endHour: 2, stableId: 'seed000001'})]
    });
    const response = ctx.actionFlightLogDelete({id: 'seed000001'}, PILOT);

    assert.strictEqual(response.ok, true);
    assert.strictEqual(response.data.id, 'seed000001');
    assert.strictEqual(flightLogSheet.data.length, 1);
    assert.deepEqual(metadataSheet.data[1], [ctx.FLIGHT_LOG_VERSION_KEY, 1]);
});

test('delete: a pilot cannot delete another pilot\'s entry, which is not removed', () => {
    const {ctx, flightLogSheet} = makeCtx({
        flightLogRows: [row({pilotName: 'luigi', startHour: 1, endHour: 2, stableId: 'seed000001'})]
    });
    const response = ctx.actionFlightLogDelete({id: 'seed000001'}, PILOT);

    assert.strictEqual(response.error.code, ctx.ERROR.FORBIDDEN);
    assert.strictEqual(flightLogSheet.data.length, 2);
});

test('delete: an admin may delete any entry', () => {
    const {ctx, flightLogSheet} = makeCtx({
        flightLogRows: [row({pilotName: 'luigi', startHour: 1, endHour: 2, stableId: 'seed000001'})]
    });
    const response = ctx.actionFlightLogDelete({id: 'seed000001'}, ADMIN);

    assert.strictEqual(response.ok, true);
    assert.strictEqual(flightLogSheet.data.length, 1);
});

// --- version counter -----------------------------------------------------------

test('the metadata version counter increments across successive mutations', () => {
    const {ctx, metadataSheet} = makeCtx();
    ctx.actionFlightLogInsert(validPayload(), PILOT);
    assert.deepEqual(metadataSheet.data[1], [ctx.FLIGHT_LOG_VERSION_KEY, 1]);

    ctx.actionFlightLogInsert(validPayload(), PILOT);
    assert.deepEqual(metadataSheet.data[1], [ctx.FLIGHT_LOG_VERSION_KEY, 2]);
});
