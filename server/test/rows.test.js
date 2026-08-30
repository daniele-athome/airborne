/**
 * How a row is found, and where it sits.
 *
 * Two small pieces that only make sense together. The sheet is re-sorted after
 * every change, so a row number means nothing between one request and the next:
 * the stable identifier is the only handle the app has on an entry, and the sort
 * spec is what keeps moving the rows out from under those numbers.
 *
 * `generateStableId` therefore has to produce something unique enough that a
 * collision never files an update against somebody else's flight, and something
 * Sheets will never read as anything but text — an all-digit id would come back
 * from `getValues()` as a number, and the text finder that locates the row would
 * stop matching it.
 *
 * `sortSpecFor` translates field names into the column numbers `Range.sort()`
 * wants. Its failure mode is silence: a name that matches nothing is dropped,
 * and the sheet is then sorted by fewer keys than intended without anybody being
 * told.
 */

const {describe, it} = require('node:test');
const assert = require('node:assert/strict');

require('./load.js');

const ID_PATTERN = /^[a-z][a-z0-9]{9}$/;

/** Runs `fn` with `Math.random` reading from `values`, then puts it back. */
function withRandom(values, fn) {
    const original = Math.random;
    let i = 0;
    Math.random = function () {
        return values[Math.min(i++, values.length - 1)];
    };
    try {
        return fn();
    } finally {
        Math.random = original;
    }
}

/** A sheet configuration with the given field names, in order. */
function configOf(names, sort) {
    const schema = names.map(function (name, index) {
        return {name: name, index: index, type: 'string'};
    });
    return {schema: schema, sort: sort};
}

describe('the id alphabet', () => {
    it('is letters first, then digits', () => {
        // The generator indexes both, and draws the first character from the
        // letters alone. That only works while one is a prefix of the other.
        assert.equal(ID_ALPHABET.indexOf(ID_LETTERS), 0);
        assert.equal(ID_ALPHABET, ID_LETTERS + '0123456789');
    });

    it('holds each character once', () => {
        assert.equal(new Set(ID_ALPHABET).size, ID_ALPHABET.length);
    });

    it('is lowercase throughout', () => {
        // `findRow` matches case, so a character that could differ only by case
        // would give two ways of naming one row.
        assert.equal(ID_ALPHABET, ID_ALPHABET.toLowerCase());
    });
});

describe('generateStableId', () => {
    it('is ten characters, starting with a letter', () => {
        assert.match(generateStableId(), ID_PATTERN);
    });

    it('never produces something Sheets could read as a number', () => {
        // The whole reason the first position is drawn from the letters. A value
        // that could be read as a number would come back from the cell as one,
        // and `matchEntireCell` compares the text representation.
        for (let i = 0; i < 200; i++) {
            const id = generateStableId();
            assert.match(id, ID_PATTERN);
            assert.equal(String(Number(id)), 'NaN');
        }
    });

    it('draws every character from the alphabet', () => {
        for (let i = 0; i < 200; i++) {
            for (const character of generateStableId()) {
                assert.ok(ID_ALPHABET.indexOf(character) >= 0, 'stray character: ' + character);
            }
        }
    });

    it('holds its shape at both ends of the random range', () => {
        assert.equal(withRandom([0], generateStableId), 'aaaaaaaaaa');
        assert.equal(withRandom([0.999999999], generateStableId), 'z999999999');
    });

    it('spends one draw per character', () => {
        // Pinned because the two positions read from different alphabets: an
        // extra or missing draw would shift every character after it.
        let calls = 0;
        const original = Math.random;
        Math.random = function () {
            calls++;
            return original();
        };
        try {
            assert.equal(generateStableId().length, 10);
        } finally {
            Math.random = original;
        }
        assert.equal(calls, 10);
    });

    it('is reproducible for a given sequence of draws', () => {
        const draws = [0, 0.5, 0.25, 0.75, 0.1, 0.9, 0.3, 0.6, 0.45, 0.05];
        assert.equal(withRandom(draws, generateStableId), withRandom(draws, generateStableId));
        assert.match(withRandom(draws, generateStableId), ID_PATTERN);
    });

    it('does not repeat itself', () => {
        // Not a proof of anything — the space is 26 * 36^9. A collision at this
        // sample size would mean the generator is broken, not unlucky.
        const seen = new Set();
        for (let i = 0; i < 2000; i++) {
            seen.add(generateStableId());
        }
        assert.equal(seen.size, 2000);
    });
});

describe('sortSpecFor', () => {
    it('maps the flight log to its two sort columns', () => {
        // startHour is schema index 3, endHour is 4; Range.sort() counts from 1.
        assert.deepEqual(sortSpecFor(flight_log_config), [{column: 4}, {column: 5}]);
    });

    it('follows the order the names were listed in', () => {
        const config = configOf(['a', 'b', 'c'], ['c', 'a']);
        assert.deepEqual(sortSpecFor(config), [{column: 3}, {column: 1}]);
    });

    it('returns nothing for an empty list', () => {
        assert.deepEqual(sortSpecFor(configOf(['a'], [])), []);
    });

    it('repeats a name that was listed twice', () => {
        assert.deepEqual(sortSpecFor(configOf(['a', 'b'], ['b', 'b'])), [{column: 2}, {column: 2}]);
    });

    it('takes the first field when two share a name', () => {
        assert.deepEqual(sortSpecFor(configOf(['a', 'a'], ['a'])), [{column: 1}]);
    });

    it('drops a name that matches no field, silently', () => {
        // Documented, not endorsed: a typo in `sort` does not fail, it just
        // removes a sort key. The guard against that is the configuration test
        // below, not this function.
        assert.deepEqual(sortSpecFor(configOf(['a', 'b'], ['b', 'typo'])), [{column: 2}]);
        assert.deepEqual(sortSpecFor(configOf(['a'], ['typo'])), []);
    });
});

describe('the flight log column configuration', () => {
    it('points stableIdColumn at the stableId field', () => {
        // `findRow` searches that one column by number, while everything else
        // addresses the field by index. The two are written down separately and
        // nothing but this keeps them aimed at the same column: aim it one to
        // the left and every update silently files itself against the notes.
        const field = flight_log_config.schema.filter(function (f) {
            return f.name === 'stableId';
        })[0];
        assert.ok(field, 'no stableId field in the schema');
        assert.equal(flight_log_config.stableIdColumn, field.index + 1);
    });

    it('ends at the identifier', () => {
        // What keeps the computed flight time safe is that it sits immediately
        // past the end of the schema: the script reads, rewrites and sorts
        // exactly `schema.length` columns and never reaches it. A field appended
        // here would be written straight onto the array formula.
        const schema = flight_log_config.schema;
        assert.equal(schema[schema.length - 1].name, 'stableId');
    });
});

describe('the flight log sort configuration', () => {
    it('names only fields that exist', () => {
        // What actually protects the live sheet: `sortSpecFor` would swallow a
        // misspelled key and leave the log sorted by one column instead of two,
        // which looks like data drifting rather than like a bug.
        const names = flight_log_config.schema.map(function (field) { return field.name; });
        for (const name of flight_log_config.sort) {
            assert.ok(names.indexOf(name) >= 0, 'sort key not in the schema: ' + name);
        }
    });

    it('names at least one', () => {
        // `Range.sort([])` is an error in Apps Script, so an empty spec would
        // throw on the next write rather than simply leave the order alone.
        assert.ok(sortSpecFor(flight_log_config).length > 0);
    });

    it('sorts by when the flight started', () => {
        // The order the app renders the log in. Pinned so that reordering the
        // schema columns cannot quietly change what the pilots see.
        assert.deepEqual(flight_log_config.sort, ['startHour', 'endHour']);
    });
});
