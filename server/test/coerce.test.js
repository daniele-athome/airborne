/**
 * Payload validation: `coerceDate` and `coerceField`.
 *
 * This is the layer that decides what a request is allowed to put in a cell, so
 * the interesting cases are the lenient ones. A field that quietly accepts the
 * wrong thing does not fail here — it fails months later, in a sheet, as a
 * number where a date should be.
 *
 * Dates never become `Date` objects: a flight date is a day, and the cell is
 * given the `yyyy-MM-dd` string so that the spreadsheet parses it in its own
 * timezone, the way it would a day typed by hand. These tests therefore assert
 * on plain strings, and nothing here can say anything about the timezone of the
 * machine running them — which is the point.
 */

const {describe, it} = require('node:test');
const assert = require('node:assert/strict');

require('./load.js');

/** A field definition, defaulting to an optional string called `value`. */
function field(overrides) {
    return Object.assign({name: 'value', type: 'string'}, overrides);
}

function assertValue(result, expected) {
    assert.equal(result.error, undefined, 'expected a value, got: ' + result.error);
    assert.equal(result.value, expected);
}

function assertRejected(result, pattern) {
    assert.equal(result.value, undefined, 'expected a refusal, got: ' + JSON.stringify(result.value));
    assert.match(result.error, pattern);
}

const dateField = field({name: 'date', type: 'date', required: true});

describe('coerceDate', () => {
    it('hands the cell a string, never a Date', () => {
        // The whole point of this layer. A Date would be written as an instant
        // and converted back to a serial using the spreadsheet timezone, so the
        // stored day would depend on that matching the script timezone.
        const result = coerceDate(dateField, '2026-08-27');
        assert.equal(typeof result.value, 'string');
        assert.equal(result.value, '2026-08-27');
    });

    it('takes the day from a full timestamp, and nothing else', () => {
        // Read off the text, not parsed: `...T23:30:00Z` is still the 27th here,
        // whatever timezone the machine or the deployment happens to be in.
        assertValue(coerceDate(dateField, '2026-08-27T14:30:00Z'), '2026-08-27');
        assertValue(coerceDate(dateField, '2026-08-27T23:30:00Z'), '2026-08-27');
        assertValue(coerceDate(dateField, '2026-08-27T00:30:00+09:00'), '2026-08-27');
    });

    it('accepts a leap day that exists', () => {
        assertValue(coerceDate(dateField, '2024-02-29'), '2024-02-29');
        assertValue(coerceDate(dateField, '2000-02-29'), '2000-02-29');
    });

    it('pads a date written with single digits', () => {
        // The cell must end up with one shape only, or two spellings of the same
        // day would sit in the column looking like different values.
        assertValue(coerceDate(dateField, '2026-8-27'), '2026-08-27');
        assertValue(coerceDate(dateField, '2026-8-7'), '2026-08-07');
    });

    it('refuses a value that is not text', () => {
        assertRejected(coerceDate(dateField, 20260827), /must be a date string/);
        assertRejected(coerceDate(dateField, null), /must be a date string/);
        assertRejected(coerceDate(dateField, {}), /must be a date string/);
        assertRejected(coerceDate(dateField, new Date(2026, 7, 27)), /must be a date string/);
    });

    it('refuses a shape it does not recognize', () => {
        // Everything `new Date(string)` used to accept and this does not. The
        // spec names two forms; anything else was being guessed at.
        assertRejected(coerceDate(dateField, '27/08/2026'), /not a valid date/);
        assertRejected(coerceDate(dateField, 'August 27, 2026'), /not a valid date/);
        assertRejected(coerceDate(dateField, '2026-08'), /not a valid date/);
    });

    it('refuses unparseable text, quoting it back', () => {
        assertRejected(coerceDate(dateField, 'yesterday'), /not a valid date: yesterday/);
        assertRejected(coerceDate(dateField, ''), /not a valid date/);
    });

    it('names the field in every message', () => {
        assert.match(coerceDate(field({name: 'departure', type: 'date'}), 7).error, /departure/);
        assert.match(coerceDate(field({name: 'departure', type: 'date'}), 'nope').error, /departure/);
    });

    /*
     * Range-checking is not a refinement here, it is what keeps the column a
     * column of dates. Nothing normalizes an impossible day any more: were one
     * to get through, Sheets would fail to read `2026-02-30` as a date and keep
     * it as text, and the app would then find a string where it expects a serial.
     */
    it('refuses a day that does not exist in its month', () => {
        assertRejected(coerceDate(dateField, '2026-02-30'), /not a valid date/);
        assertRejected(coerceDate(dateField, '2026-04-31'), /not a valid date/);
        assertRejected(coerceDate(dateField, '2026-02-29'), /not a valid date/);
        assertRejected(coerceDate(dateField, '1900-02-29'), /not a valid date/);
    });

    it('refuses an out-of-range month or day', () => {
        assertRejected(coerceDate(dateField, '2026-13-01'), /not a valid date/);
        assertRejected(coerceDate(dateField, '2026-00-10'), /not a valid date/);
        assertRejected(coerceDate(dateField, '2026-08-00'), /not a valid date/);
    });

    it('accepts the last day of every month', () => {
        const lengths = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
        for (let month = 1; month <= 12; month++) {
            const day = '2026-' + (month < 10 ? '0' + month : month) + '-' + lengths[month - 1];
            assertValue(coerceDate(dateField, day), day);
            assert.match(coerceDate(dateField, '2026-' + month + '-' + (lengths[month - 1] + 1)).error, /not a valid date/);
        }
    });
});

describe('coerceField: absence', () => {
    for (const absent of [undefined, null, '']) {
        it('refuses a required field given ' + JSON.stringify(absent), () => {
            assertRejected(coerceField(field({required: true}), absent), /Missing required field: value/);
        });

        it('empties an optional field given ' + JSON.stringify(absent), () => {
            assertValue(coerceField(field({nullable: true}), absent), '');
        });
    }

    it('empties an optional number rather than zeroing it', () => {
        // The cell is cleared, not set to 0: an unknown fuel load and a zero fuel
        // load are not the same reading.
        assertValue(coerceField(field({type: 'number', nullable: true}), null), '');
    });

    it('treats zero as a value, not as absence', () => {
        // `raw === ''` is strict, so 0 survives. It has to: a zero fuel price is
        // a real one.
        assertValue(coerceField(field({type: 'number', required: true}), 0), 0);
    });

    it('refuses a required date before trying to parse it', () => {
        assertRejected(coerceField(dateField, undefined), /Missing required field: date/);
    });
});

describe('coerceField: strings', () => {
    it('passes text through', () => {
        assertValue(coerceField(field({}), 'Ciampino'), 'Ciampino');
    });

    it('does not trim', () => {
        // Only names are canonicalized, and that happens in the identity layer.
        // An origin keeps the spacing it was sent with.
        assertValue(coerceField(field({}), '  Urbe  '), '  Urbe  ');
    });

    it('refuses a non-string', () => {
        assertRejected(coerceField(field({}), 42), /must be a string/);
        assertRejected(coerceField(field({}), true), /must be a string/);
        assertRejected(coerceField(field({}), ['a']), /must be a string/);
    });

    it('enforces an allowed set', () => {
        const restricted = field({values: ['VFR', 'IFR']});
        assertValue(coerceField(restricted, 'IFR'), 'IFR');
        assertRejected(coerceField(restricted, 'ifr'), /must be one of: VFR, IFR/);
    });
});

describe('coerceField: numbers', () => {
    it('accepts a number', () => {
        assertValue(coerceField(field({type: 'number'}), 12.5), 12.5);
    });

    it('accepts a numeric string', () => {
        assertValue(coerceField(field({type: 'number'}), '12.5'), 12.5);
    });

    it('refuses text that is not a number', () => {
        assertRejected(coerceField(field({type: 'number'}), 'abc'), /must be a number/);
    });

    it('refuses infinities and NaN', () => {
        assertRejected(coerceField(field({type: 'number'}), Infinity), /must be a number/);
        assertRejected(coerceField(field({type: 'number'}), NaN), /must be a number/);
        assertRejected(coerceField(field({type: 'number'}), '1e999'), /must be a number/);
    });

    it('refuses a fraction where an integer is required', () => {
        assertValue(coerceField(field({type: 'integer'}), 2), 2);
        assertRejected(coerceField(field({type: 'integer'}), 1.5), /must be an integer/);
    });

    it('enforces an allowed set', () => {
        const restricted = field({type: 'integer', values: [1, 2]});
        assertValue(coerceField(restricted, 2), 2);
        assertRejected(coerceField(restricted, 3), /must be one of: 1, 2/);
    });

    it('coerces anything Number() understands', () => {
        // Documented, not endorsed: the number branch runs `Number(raw)` on
        // whatever arrives, so a boolean or a one-element array becomes a
        // reading. Nothing in the app sends these, and the sheet would show a
        // plausible 0 if one ever did.
        assertValue(coerceField(field({type: 'number'}), true), 1);
        assertValue(coerceField(field({type: 'number'}), [5]), 5);
    });
});

describe('coerceField: dispatch', () => {
    it('hands date fields to coerceDate', () => {
        assertValue(coerceField(dateField, '2026-08-27'), '2026-08-27');
        assertRejected(coerceField(dateField, 'yesterday'), /not a valid date/);
    });

    it('refuses a type it does not know', () => {
        assertRejected(coerceField(field({type: 'duration'}), 'x'), /Unsupported field type for value/);
    });

    it('handles every type the flight log schema uses', () => {
        // Guards against a field being added with a type nothing implements: the
        // row would then be refused at runtime with "Unsupported field type".
        const samples = {string: 'x', number: 1, integer: 1, date: '2026-08-27'};
        for (const schemaField of flight_log_config.schema) {
            assert.ok(
                Object.prototype.hasOwnProperty.call(samples, schemaField.type),
                'no sample for type ' + schemaField.type + ' of field ' + schemaField.name
            );
            assert.equal(
                coerceField(schemaField, samples[schemaField.type]).error,
                undefined,
                'field ' + schemaField.name + ' rejected a valid ' + schemaField.type
            );
        }
    });
});
