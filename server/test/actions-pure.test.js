'use strict';

const test = require('node:test');
const assert = require('node:assert');
const {loadContext} = require('./helpers');

function makeCtx() {
    return loadContext(['00_config.js', '10_protocol.js', '60_actions.js'], {});
}

// --- coerceField -----------------------------------------------------------

test('coerceField: a missing required field is an error', () => {
    const ctx = makeCtx();
    const field = {name: 'origin', type: 'string', required: true};
    assert.match(ctx.coerceField(field, undefined).error, /Missing required field/);
    assert.match(ctx.coerceField(field, null).error, /Missing required field/);
    assert.match(ctx.coerceField(field, '').error, /Missing required field/);
});

test('coerceField: a missing optional field resolves to an empty string', () => {
    const ctx = makeCtx();
    const field = {name: 'notes', type: 'string', nullable: true};
    assert.strictEqual(ctx.coerceField(field, undefined).value, '');
    assert.strictEqual(ctx.coerceField(field, null).value, '');
});

test('coerceField: string type rejects non-strings and enforces the enum', () => {
    const ctx = makeCtx();
    const field = {name: 'origin', type: 'string'};
    assert.strictEqual(ctx.coerceField(field, 'LIML').value, 'LIML');
    assert.match(ctx.coerceField(field, 42).error, /must be a string/);

    const enumField = {name: 'origin', type: 'string', values: ['LIML', 'LIME']};
    assert.strictEqual(ctx.coerceField(enumField, 'LIML').value, 'LIML');
    assert.match(ctx.coerceField(enumField, 'XXXX').error, /must be one of/);
});

test('coerceField: number type coerces numeric strings and rejects NaN/Infinity', () => {
    const ctx = makeCtx();
    const field = {name: 'startHour', type: 'number'};
    assert.strictEqual(ctx.coerceField(field, 12.5).value, 12.5);
    assert.strictEqual(ctx.coerceField(field, '12.5').value, 12.5);
    assert.match(ctx.coerceField(field, 'nope').error, /must be a number/);
    assert.match(ctx.coerceField(field, Infinity).error, /must be a number/);
    assert.match(ctx.coerceField(field, NaN).error, /must be a number/);
});

test('coerceField: integer type rejects non-integral numbers', () => {
    const ctx = makeCtx();
    const field = {name: 'count', type: 'integer'};
    assert.strictEqual(ctx.coerceField(field, 3).value, 3);
    assert.match(ctx.coerceField(field, 3.2).error, /must be an integer/);
});

test('coerceField: number enum values are enforced', () => {
    const ctx = makeCtx();
    const field = {name: 'rating', type: 'number', values: [1, 2, 3]};
    assert.strictEqual(ctx.coerceField(field, 2).value, 2);
    assert.match(ctx.coerceField(field, 4).error, /must be one of/);
});

test('coerceField: an unsupported type is an error', () => {
    const ctx = makeCtx();
    assert.match(ctx.coerceField({name: 'x', type: 'object'}, {}).error, /Unsupported field type/);
});

// --- coerceDate --------------------------------------------------------------

test('coerceDate: a Date instance passes through unchanged', () => {
    const ctx = makeCtx();
    const field = {name: 'date', type: 'date'};
    // Built with the sandbox's own Date constructor: `instanceof Date` inside
    // coerceDate checks against *that* realm's Date, not this file's.
    const date = new ctx.Date(2024, 0, 15);
    assert.strictEqual(ctx.coerceDate(field, date).value, date);
});

test('coerceDate: a plain yyyy-MM-dd string becomes local midnight', () => {
    const ctx = makeCtx();
    const field = {name: 'date', type: 'date'};
    const result = ctx.coerceDate(field, '2024-03-05');
    assert.strictEqual(result.value.getFullYear(), 2024);
    assert.strictEqual(result.value.getMonth(), 2);
    assert.strictEqual(result.value.getDate(), 5);
    assert.strictEqual(result.value.getHours(), 0);
    assert.strictEqual(result.value.getMinutes(), 0);
});

test('coerceDate: a full ISO timestamp keeps its time component', () => {
    const ctx = makeCtx();
    const field = {name: 'date', type: 'date'};
    const result = ctx.coerceDate(field, '2024-03-05T10:30:00.000Z');
    assert.strictEqual(result.value.toISOString(), '2024-03-05T10:30:00.000Z');
});

test('coerceDate: rejects non-date-strings and invalid dates', () => {
    const ctx = makeCtx();
    const field = {name: 'date', type: 'date'};
    assert.match(ctx.coerceDate(field, 42).error, /must be a date string/);
    assert.match(ctx.coerceDate(field, 'not a date').error, /not a valid date/);
});

// --- generateStableId --------------------------------------------------------

test('generateStableId: a 10 char id starting with a letter, from the expected alphabet', () => {
    const ctx = makeCtx();
    for (let i = 0; i < 50; i++) {
        const id = ctx.generateStableId();
        assert.match(id, /^[a-z][a-z0-9]{9}$/);
    }
});

// --- buildRowValues ------------------------------------------------------------

function schema(ctx) {
    return ctx.flight_log_config.schema;
}

test('buildRowValues (insert): stamps createdAt and a stableId, nulls the managed empty field', () => {
    const ctx = makeCtx();
    const payload = {
        date: '2024-03-05',
        startHour: 1,
        endHour: 2,
        origin: 'LIML',
        destination: 'LIME'
    };
    const built = ctx.buildRowValues(schema(ctx), payload, null, {pilotName: 'mario'});
    assert.ok(!built.error);

    const createdAtIndex = schema(ctx).find((f) => f.name === 'createdAt').index;
    const stableIdIndex = schema(ctx).find((f) => f.name === 'stableId').index;
    const flightTimeIndex = schema(ctx).find((f) => f.name === 'flightTime').index;
    const pilotNameIndex = schema(ctx).find((f) => f.name === 'pilotName').index;

    assert.ok(built.values[createdAtIndex] instanceof ctx.Date);
    assert.match(built.values[stableIdIndex], /^[a-z][a-z0-9]{9}$/);
    assert.strictEqual(built.values[flightTimeIndex], null);
    assert.strictEqual(built.values[pilotNameIndex], 'mario');
    assert.strictEqual(built.rowId, built.values[stableIdIndex]);
});

test('buildRowValues (insert): propagates a coercion error', () => {
    const ctx = makeCtx();
    const payload = {date: '2024-03-05', startHour: 'nope', endHour: 2, origin: 'LIML', destination: 'LIME'};
    const built = ctx.buildRowValues(schema(ctx), payload, null, {pilotName: 'mario'});
    assert.match(built.error, /startHour/);
});

test('buildRowValues (update): preserves immutable fields and keeps unspecified fields as-is', () => {
    const ctx = makeCtx();
    const s = schema(ctx);
    const createdAtIndex = s.find((f) => f.name === 'createdAt').index;
    const stableIdIndex = s.find((f) => f.name === 'stableId').index;
    const flightTimeIndex = s.find((f) => f.name === 'flightTime').index;
    const originalCreatedAt = new Date(2020, 0, 1);

    const existing = [];
    existing[createdAtIndex] = originalCreatedAt;
    existing[s.find((f) => f.name === 'date').index] = new Date(2024, 0, 1);
    existing[s.find((f) => f.name === 'pilotName').index] = 'mario';
    existing[s.find((f) => f.name === 'startHour').index] = 1;
    existing[s.find((f) => f.name === 'endHour').index] = 2;
    existing[s.find((f) => f.name === 'origin').index] = 'LIML';
    existing[s.find((f) => f.name === 'destination').index] = 'LIME';
    existing[s.find((f) => f.name === 'fuel').index] = 10;
    existing[flightTimeIndex] = 'stale';
    existing[stableIdIndex] = 'abc0000000';

    // Only touch endHour: everything else should be preserved except the managed-empty field.
    const built = ctx.buildRowValues(s, {endHour: 5}, existing, {pilotName: 'mario'});
    assert.ok(!built.error);
    assert.strictEqual(built.values[createdAtIndex], originalCreatedAt);
    assert.strictEqual(built.values[stableIdIndex], 'abc0000000');
    assert.strictEqual(built.rowId, 'abc0000000');
    assert.strictEqual(built.values[s.find((f) => f.name === 'startHour').index], 1);
    assert.strictEqual(built.values[s.find((f) => f.name === 'endHour').index], 5);
    assert.strictEqual(built.values[s.find((f) => f.name === 'fuel').index], 10);
    // flightTime is recomputed downstream: always reset, never carried over.
    assert.strictEqual(built.values[flightTimeIndex], null);
});

test('buildRowValues: the identity field is always taken from identityValues, ignoring the payload', () => {
    const ctx = makeCtx();
    const s = schema(ctx);
    const pilotNameIndex = s.find((f) => f.name === 'pilotName').index;
    const built = ctx.buildRowValues(s, {
        date: '2024-03-05', startHour: 1, endHour: 2, origin: 'LIML', destination: 'LIME',
        pilotName: 'someone-else'
    }, null, {pilotName: 'mario'});
    assert.strictEqual(built.values[pilotNameIndex], 'mario');
});
