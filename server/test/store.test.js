'use strict';

const test = require('node:test');
const assert = require('node:assert');
const {loadContext} = require('./helpers');
const {FakeSheet, fakeSpreadsheetApp, fakeProperties} = require('./fake-apps-script');

function makeCtx(sheets, properties) {
    const {SpreadsheetApp, state: spreadsheetState} = fakeSpreadsheetApp(sheets);
    const ctx = loadContext(['00_config.js', '40_store.js'], Object.assign({SpreadsheetApp}, fakeProperties(properties)));
    return {ctx, spreadsheetState};
}

// A generic 3-column sheet config, independent of flight_log_config: headers in
// row 1, stable id in column 3, sortable by "b" (column 2).
const sheetConfig = {
    headerRows: 1,
    stableIdColumn: 3,
    schema: [{name: 'a', index: 0}, {name: 'b', index: 1}, {name: 'id', index: 2}],
    sort: ['b']
};

// --- openSheetByName / openMetadataSheet / openFlightLogSheet ----------------

test('openSheetByName returns the sheet when it exists', () => {
    const sheet = new FakeSheet('Metadata', [['key', 'value']]);
    const {ctx} = makeCtx({Metadata: sheet}, {});
    assert.strictEqual(ctx.openSheetByName('Metadata'), sheet);
});

test('openSheetByName throws with the sheet name when missing', () => {
    const {ctx} = makeCtx({}, {});
    assert.throws(() => ctx.openSheetByName('Nope'), /Nope/);
});

test('openMetadataSheet/openFlightLogSheet resolve the sheet name from script properties', () => {
    const metadata = new FakeSheet('Metadata');
    const flightLog = new FakeSheet('Registro voli');
    const {ctx} = makeCtx(
        {Metadata: metadata, 'Registro voli': flightLog},
        {METADATA_SHEET_NAME: 'Metadata', FLIGHT_LOG_SHEET_NAME: 'Registro voli'}
    );
    assert.strictEqual(ctx.openMetadataSheet(), metadata);
    assert.strictEqual(ctx.openFlightLogSheet(), flightLog);
});

test('openMetadataSheet throws when the script property is not configured', () => {
    const {ctx} = makeCtx({}, {});
    assert.throws(() => ctx.openMetadataSheet(), /METADATA_SHEET_NAME/);
});

// --- findRow -------------------------------------------------------------------

test('findRow: an empty sheet (header only) is reported as not found', () => {
    const sheet = new FakeSheet('S', [['a', 'b', 'id']]);
    const {ctx} = makeCtx({S: sheet}, {});
    assert.strictEqual(ctx.findRow(sheetConfig, sheet, 'abc'), -1);
});

test('findRow: locates the row whose stable id column matches exactly', () => {
    const sheet = new FakeSheet('S', [
        ['a', 'b', 'id'],
        [1, 2, 'row-1'],
        [3, 4, 'row-2']
    ]);
    const {ctx} = makeCtx({S: sheet}, {});
    assert.strictEqual(ctx.findRow(sheetConfig, sheet, 'row-2'), 3);
    assert.strictEqual(ctx.findRow(sheetConfig, sheet, 'row-1'), 2);
});

test('findRow: no match returns -1', () => {
    const sheet = new FakeSheet('S', [['a', 'b', 'id'], [1, 2, 'row-1']]);
    const {ctx} = makeCtx({S: sheet}, {});
    assert.strictEqual(ctx.findRow(sheetConfig, sheet, 'missing'), -1);
});

test('findRow: the match is case sensitive', () => {
    const sheet = new FakeSheet('S', [['a', 'b', 'id'], [1, 2, 'Row-1']]);
    const {ctx} = makeCtx({S: sheet}, {});
    assert.strictEqual(ctx.findRow(sheetConfig, sheet, 'row-1'), -1);
    assert.strictEqual(ctx.findRow(sheetConfig, sheet, 'Row-1'), 2);
});

test('findRow: the match is against the whole cell, not a substring', () => {
    const sheet = new FakeSheet('S', [['a', 'b', 'id'], [1, 2, 'row-123']]);
    const {ctx} = makeCtx({S: sheet}, {});
    assert.strictEqual(ctx.findRow(sheetConfig, sheet, 'row-1'), -1);
});

// --- readRow / writeRow / deleteRow -----------------------------------------

test('readRow reads exactly the configured row width', () => {
    const sheet = new FakeSheet('S', [['a', 'b', 'id'], [1, 2, 'row-1']]);
    const {ctx} = makeCtx({S: sheet}, {});
    assert.deepStrictEqual(ctx.readRow(sheetConfig, sheet, 2), [1, 2, 'row-1']);
});

test('writeRow overwrites the given row in place', () => {
    const sheet = new FakeSheet('S', [['a', 'b', 'id'], [1, 2, 'row-1']]);
    const {ctx} = makeCtx({S: sheet}, {});
    ctx.writeRow(sheetConfig, sheet, 2, [9, 9, 'row-1']);
    assert.deepStrictEqual(sheet.data[1], [9, 9, 'row-1']);
});

test('deleteRow removes the row and shifts the following ones up', () => {
    const sheet = new FakeSheet('S', [['a', 'b', 'id'], [1, 2, 'row-1'], [3, 4, 'row-2']]);
    const {ctx} = makeCtx({S: sheet}, {});
    ctx.deleteRow(sheet, 2);
    assert.deepStrictEqual(sheet.data, [['a', 'b', 'id'], [3, 4, 'row-2']]);
});

test('appendRow adds a new row at the end', () => {
    const sheet = new FakeSheet('S', [['a', 'b', 'id'], [1, 2, 'row-1']]);
    const {ctx} = makeCtx({S: sheet}, {});
    ctx.appendRow(sheet, [3, 4, 'row-2']);
    assert.deepStrictEqual(sheet.data, [['a', 'b', 'id'], [1, 2, 'row-1'], [3, 4, 'row-2']]);
});

// --- sortSpecFor / sortSheet ----------------------------------------------------

test('sortSpecFor maps configured sort field names to their 1-based column numbers', () => {
    const {ctx} = makeCtx({}, {});
    assert.deepEqual(ctx.sortSpecFor(sheetConfig), [{column: 2}]);
});

test('sortSpecFor silently skips a sort field name absent from the schema', () => {
    const {ctx} = makeCtx({}, {});
    const config = Object.assign({}, sheetConfig, {sort: ['b', 'nope']});
    assert.deepEqual(ctx.sortSpecFor(config), [{column: 2}]);
});

test('sortSheet reorders the data rows in place by the configured sort columns', () => {
    const sheet = new FakeSheet('S', [
        ['a', 'b', 'id'],
        [1, 30, 'row-1'],
        [2, 10, 'row-2'],
        [3, 20, 'row-3']
    ]);
    const {ctx} = makeCtx({S: sheet}, {});
    ctx.sortSheet(sheetConfig, sheet);
    assert.deepStrictEqual(sheet.data, [
        ['a', 'b', 'id'],
        [2, 10, 'row-2'],
        [3, 20, 'row-3'],
        [1, 30, 'row-1']
    ]);
});

test('sortSheet does nothing on a header-only (or empty) sheet', () => {
    const sheet = new FakeSheet('S', [['a', 'b', 'id']]);
    const {ctx} = makeCtx({S: sheet}, {});
    ctx.sortSheet(sheetConfig, sheet);
    assert.deepStrictEqual(sheet.data, [['a', 'b', 'id']]);
});

// --- updateVersionMetadata ------------------------------------------------------

test('updateVersionMetadata appends a new counter row at 1 when the key is not found', () => {
    const sheet = new FakeSheet('Metadata', [['key', 'value']]);
    const {ctx} = makeCtx({Metadata: sheet}, {METADATA_SHEET_NAME: 'Metadata'});
    ctx.updateVersionMetadata('flight_log.hash');
    assert.deepEqual(sheet.data[1], ['flight_log.hash', 1]);
});

test('updateVersionMetadata increments an existing numeric counter', () => {
    const sheet = new FakeSheet('Metadata', [['key', 'value'], ['flight_log.hash', 4]]);
    const {ctx} = makeCtx({Metadata: sheet}, {METADATA_SHEET_NAME: 'Metadata'});
    ctx.updateVersionMetadata('flight_log.hash');
    assert.deepEqual(sheet.data[1], ['flight_log.hash', 5]);
});

test('updateVersionMetadata resets a non-numeric counter to 1', () => {
    const sheet = new FakeSheet('Metadata', [['key', 'value'], ['flight_log.hash', 'oops']]);
    const {ctx} = makeCtx({Metadata: sheet}, {METADATA_SHEET_NAME: 'Metadata'});
    ctx.updateVersionMetadata('flight_log.hash');
    assert.deepEqual(sheet.data[1], ['flight_log.hash', 1]);
});

// --- commitChanges ---------------------------------------------------------------

test('commitChanges flushes the spreadsheet', () => {
    const {ctx, spreadsheetState} = makeCtx({}, {});
    ctx.commitChanges();
    assert.strictEqual(spreadsheetState.flushCalls, 1);
});

// --- readMetadata --------------------------------------------------------------

test('readMetadata: a header-only sheet yields an empty store', () => {
    const sheet = new FakeSheet('Metadata', [['key', 'value']]);
    const {ctx} = makeCtx({Metadata: sheet}, {METADATA_SHEET_NAME: 'Metadata'});
    assert.deepEqual(ctx.readMetadata(), {});
});

test('readMetadata: reads key/value rows into a plain object, stringifying values', () => {
    const sheet = new FakeSheet('Metadata', [
        ['key', 'value'],
        ['token.mario', 'secret'],
        ['flight_log.hash', 7]
    ]);
    const {ctx} = makeCtx({Metadata: sheet}, {METADATA_SHEET_NAME: 'Metadata'});
    assert.deepEqual(ctx.readMetadata(), {'token.mario': 'secret', 'flight_log.hash': '7'});
});

test('readMetadata: null/undefined values become an empty string, and empty keys are skipped', () => {
    const sheet = new FakeSheet('Metadata', [
        ['key', 'value'],
        ['a', null],
        ['', 'ignored because the key is empty'],
        ['b', undefined]
    ]);
    const {ctx} = makeCtx({Metadata: sheet}, {METADATA_SHEET_NAME: 'Metadata'});
    assert.deepEqual(ctx.readMetadata(), {a: '', b: ''});
});
