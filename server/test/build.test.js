/**
 * Building a row.
 *
 * `buildRowValues` is where a request stops being a request and becomes cells.
 * Everything before it decides what is allowed; this decides what is written,
 * and it writes the whole row every time — including the columns the caller
 * never mentioned. So the interesting question is not what an update changes but
 * what it leaves alone: a field missing from the payload must come out of the
 * existing row unharmed, because there is no partial write to fall back on.
 *
 * The identity column is the exception on purpose. It is never read from the
 * payload here, only from the values the identity resolvers handed down, which
 * is what keeps "who may write this name" and "write this name" from being the
 * same decision made twice.
 */

const {describe, it} = require('node:test');
const assert = require('node:assert/strict');

require('./load.js');

const SCHEMA = flight_log_config.schema;

/** Column index by field name, so the assertions read like the sheet. */
const AT = {};
for (const field of SCHEMA) {
    AT[field.name] = field.index;
}

/** A payload with every required field filled in. */
function flight(overrides) {
    return Object.assign({
        date: '2026-08-27',
        startHour: 1200.5,
        endHour: 1201.8,
        origin: 'LIRU',
        destination: 'LIRE'
    }, overrides);
}

/** A row as `readRow` would hand it back. */
function storedRow(overrides) {
    const row = [
        new Date(2025, 0, 1, 9, 30),
        new Date(2026, 0, 2),
        'Bob',
        1000,
        1001.5,
        'LIRU',
        'LIRE',
        20,
        1.9,
        'all fine',
        '1:30',
        'ab12cd34ef'
    ];
    for (const name of Object.keys(overrides || {})) {
        row[AT[name]] = overrides[name];
    }
    return row;
}

function inserted(payload, identityValues) {
    return buildRowValues(SCHEMA, payload, null, identityValues || {pilotName: 'Bob'});
}

function updated(payload, existing, identityValues) {
    return buildRowValues(SCHEMA, payload, existing || storedRow(), identityValues || {pilotName: 'Bob'});
}

function built(result) {
    assert.equal(result.error, undefined, 'expected a row, got: ' + result.error);
    return result.values;
}

describe('insert', () => {
    it('puts every field in its own column', () => {
        const values = built(inserted(flight()));
        assert.equal(values.length, SCHEMA.length);
        assert.equal(values[AT.startHour], 1200.5);
        assert.equal(values[AT.endHour], 1201.8);
        assert.equal(values[AT.origin], 'LIRU');
        assert.equal(values[AT.destination], 'LIRE');
        assert.equal(values[AT.date].getFullYear(), 2026);
    });

    it('stamps createdAt with the current time', () => {
        const before = Date.now();
        const values = built(inserted(flight()));
        assert.ok(values[AT.createdAt] instanceof Date);
        assert.ok(values[AT.createdAt].getTime() >= before);
        assert.ok(values[AT.createdAt].getTime() <= Date.now());
    });

    it('generates the identifier and reports it back', () => {
        // The caller answers the client with `rowId`, so the two must be the same
        // string: an id in the sheet that the app was never told about is a row
        // it can never update.
        const result = inserted(flight());
        assert.match(result.rowId, /^[a-z][a-z0-9]{9}$/);
        assert.equal(result.values[AT.stableId], result.rowId);
    });

    it('takes the name from the identity values, not from the payload', () => {
        // The payload's own claim was already weighed by `resolveIdentityForInsert`;
        // reading it again here would be a second, unchecked decision.
        const values = built(inserted(flight({pilotName: 'Alice'}), {pilotName: 'Bob'}));
        assert.equal(values[AT.pilotName], 'Bob');
    });

    it('leaves the computed column empty', () => {
        assert.equal(built(inserted(flight()))[AT.flightTime], null);
    });

    it('empties an optional field nobody filled in', () => {
        const values = built(inserted(flight()));
        assert.equal(values[AT.fuel], '');
        assert.equal(values[AT.notes], '');
    });

    it('refuses a payload missing a required field', () => {
        assert.match(inserted(flight({origin: undefined})).error, /Missing required field: origin/);
        assert.match(inserted({}).error, /Missing required field/);
    });

    it('reports the bad field rather than building half a row', () => {
        assert.equal(inserted(flight({startHour: 'noon'})).values, undefined);
        assert.match(inserted(flight({startHour: 'noon'})).error, /startHour must be a number/);
    });

    it('ignores a key the schema does not know', () => {
        const values = built(inserted(flight({id: 'zz', aircraft: 'I-ABCD'})));
        assert.equal(values.length, SCHEMA.length);
    });
});

describe('update', () => {
    it('changes what the payload names', () => {
        const values = built(updated({origin: 'LIRA', fuel: 35}));
        assert.equal(values[AT.origin], 'LIRA');
        assert.equal(values[AT.fuel], 35);
    });

    it('leaves untouched everything the payload does not name', () => {
        // The whole row is rewritten on every update, so silence has to mean
        // "keep it", not "clear it".
        const existing = storedRow();
        const values = built(updated({origin: 'LIRA'}, existing));
        for (const field of SCHEMA) {
            if (['origin', 'flightTime'].indexOf(field.name) >= 0) {
                continue;
            }
            assert.deepEqual(values[field.index], existing[field.index], 'lost ' + field.name);
        }
    });

    it('coerces what it does change', () => {
        const values = built(updated({date: '2026-09-01', startHour: '1300'}));
        assert.ok(values[AT.date] instanceof Date);
        assert.equal(values[AT.date].getMonth() + 1, 9);
        assert.equal(values[AT.startHour], 1300);
    });

    it('refuses to blank a required field', () => {
        assert.match(updated({origin: ''}).error, /Missing required field: origin/);
    });

    it('keeps createdAt even when the payload sends one', () => {
        const existing = storedRow();
        const values = built(updated({createdAt: '2026-08-27'}, existing));
        assert.deepEqual(values[AT.createdAt], existing[AT.createdAt]);
    });

    it('keeps the identifier even when the payload sends one', () => {
        // Letting it move would hand the client a way to point an entry at
        // another one, or to make an entry unreachable.
        const result = updated({stableId: 'zzzzzzzzzz'});
        assert.equal(result.values[AT.stableId], 'ab12cd34ef');
        assert.equal(result.rowId, 'ab12cd34ef');
    });

    it('writes the name the resolver decided on', () => {
        // An update may hand a row over to the maintenance name without the
        // payload naming any column: the decision arrives through identityValues.
        const values = built(updated({}, storedRow(), {pilotName: 'NO PILOT'}));
        assert.equal(values[AT.pilotName], 'NO PILOT');
    });

    it('clears the computed column on every update', () => {
        // Documented, not endorsed. `managed: 'empty'` does not distinguish
        // insert from update, so a formula living in that column is erased by the
        // first edit of the row — including an edit that changes nothing else.
        const existing = storedRow();
        assert.equal(existing[AT.flightTime], '1:30');
        assert.equal(built(updated({}, existing))[AT.flightTime], null);
    });

    it('returns a row of the right width', () => {
        assert.equal(built(updated({origin: 'LIRA'})).length, SCHEMA.length);
    });
});

describe('the schema it is handed', () => {
    it('numbers its columns 0 to n-1, once each', () => {
        // `buildRowValues` prefills by position and writes by index, and
        // `readRow`/`writeRow` ask the sheet for exactly `schema.length` columns.
        // A gap or a repeat would misalign every one of those against the others.
        const indices = SCHEMA.map(function (field) { return field.index; }).sort(function (a, b) { return a - b; });
        assert.deepEqual(indices, SCHEMA.map(function (_, i) { return i; }));
    });

    it('writes by index, not by the order the fields are declared in', () => {
        const schema = [
            {name: 'second', index: 1, type: 'string', required: true},
            {name: 'first', index: 0, type: 'string', required: true}
        ];
        const result = buildRowValues(schema, {first: 'a', second: 'b'}, null, {});
        assert.deepEqual(result.values, ['a', 'b']);
    });

    it('holds an immutable field that nothing else protects', () => {
        // For the flight log this guard never fires on its own: both immutable
        // fields are also managed, and their managed branches already read the
        // existing value back. The two mechanisms overlap, so only a schema with
        // an immutable field that is not managed shows what the flag does.
        const schema = [{name: 'serial', index: 0, type: 'string', immutable: true}];
        assert.deepEqual(buildRowValues(schema, {serial: 'new'}, ['old'], {}).values, ['old']);
    });

    it('lets an immutable field be set the first time', () => {
        const schema = [{name: 'serial', index: 0, type: 'string', immutable: true}];
        assert.deepEqual(buildRowValues(schema, {serial: 'new'}, null, {}).values, ['new']);
    });

    it('keeps an existing identifier even when it is free to change it', () => {
        // The immutable flag short-circuits the managed branch for the flight
        // log, so this is the only way to reach the branch that reads the id back
        // out of the row. Same answer either way: an existing id is never
        // regenerated.
        const schema = [{name: 'stableId', index: 0, type: 'string', managed: 'stableId'}];
        const result = buildRowValues(schema, {}, ['ab12cd34ef'], {});
        assert.deepEqual(result.values, ['ab12cd34ef']);
        assert.equal(result.rowId, 'ab12cd34ef');
    });
});
