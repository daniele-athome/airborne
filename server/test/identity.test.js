/**
 * The authorization matrix.
 *
 * An admin does anything. A pilot files, edits and removes entries under their
 * own name; does the same to entries under the maintenance name; and may hand
 * one of their own entries over to that name, one way only.
 *
 * Those rules are not a predicate over a single name: what a request may write
 * depends on the name already in the row. Delete asks a strict subset of what
 * update asks — may this caller touch this row at all — so the one asymmetry
 * left to hold in place is that a maintenance row cannot be taken back. If
 * someone ever folds the three resolvers into one check, it is
 * `maintenance row, claimed back` that goes red first.
 */

const {describe, it, beforeEach} = require('node:test');
const assert = require('node:assert/strict');

require('./load.js');
const {setScriptProperties} = require('./stubs.js');

/** The maintenance name this deployment is configured with. */
const NO_PILOT = 'NO PILOT';

const SELF = 'Bob';
const OTHER = 'Alice';

/** The column the identity lives in, asked of the schema rather than assumed. */
const PILOT_INDEX = identityFields(flight_log_config)[0].index;

function pilot(name) {
    return {pilotName: name === undefined ? SELF : name, role: ROLE_PILOT};
}

function admin() {
    return {pilotName: 'Root', role: ROLE_ADMIN};
}

/** An existing row filed under `name`; only the identity column matters here. */
function rowFiledUnder(name) {
    const row = [];
    for (let i = 0; i < flight_log_config.schema.length; i++) {
        row.push('');
    }
    row[PILOT_INDEX] = name;
    return row;
}

/**
 * A payload claiming `name`.
 *
 * `undefined` means no claim at all — the key is absent, which is a different
 * branch from a key present and null, tested separately.
 */
function claiming(name) {
    return name === undefined ? {} : {pilotName: name};
}

function assertWrites(result, expected) {
    assert.equal(result.error, undefined, 'expected success, got: ' + result.error);
    assert.equal(result.values.pilotName, expected);
}

function assertDenied(result, pattern, code) {
    assert.equal(result.values, undefined, 'expected a refusal, got a value to write');
    assert.equal(result.code, code || ERROR.FORBIDDEN);
    assert.match(result.error, pattern);
}

beforeEach(() => {
    setScriptProperties({NO_PILOT_NAME: NO_PILOT});
});

describe('insert', () => {
    it('defaults to the authenticated pilot when nothing is claimed', () => {
        assertWrites(resolveIdentityForInsert(flight_log_config, claiming(undefined), pilot()), SELF);
    });

    it('canonicalizes a claim on the pilot\'s own name', () => {
        // The spelling that reaches the sheet is the server's, not the caller's:
        // otherwise a pilot could file rows under a variant of their own name and
        // scatter their history across spellings.
        assertWrites(resolveIdentityForInsert(flight_log_config, claiming('  bOb '), pilot()), SELF);
    });

    it('accepts the maintenance name, canonicalized', () => {
        assertWrites(resolveIdentityForInsert(flight_log_config, claiming(' no pilot '), pilot()), NO_PILOT);
    });

    it('refuses another pilot\'s name', () => {
        assertDenied(resolveIdentityForInsert(flight_log_config, claiming(OTHER), pilot()), /add entry as/);
    });

    it('lets an admin file under any name, as typed', () => {
        assertWrites(resolveIdentityForInsert(flight_log_config, claiming('  Zoe '), admin()), 'Zoe');
    });

    it('defaults an admin to their own name too', () => {
        assertWrites(resolveIdentityForInsert(flight_log_config, claiming(undefined), admin()), 'Root');
    });

    it('rejects a non-string claim before deciding anything', () => {
        assertDenied(
            resolveIdentityForInsert(flight_log_config, claiming(42), pilot()),
            /must be a string/,
            ERROR.BAD_REQUEST
        );
    });

    it('treats an explicit null as no claim', () => {
        assertWrites(resolveIdentityForInsert(flight_log_config, claiming(null), pilot()), SELF);
    });
});

describe('update', () => {
    /*
     * owner  — the name already in the row
     * claim  — what the request asks for, `undefined` meaning it asks for nothing
     * writes — the name that must reach the sheet
     * denies — the message that must come back instead
     */
    const MATRIX = [
        {what: 'own row, unclaimed',            owner: SELF,     claim: undefined, writes: SELF},
        {what: 'own row, claimed again',        owner: SELF,     claim: '  bOb ',  writes: SELF},
        {what: 'own row, handed over',          owner: SELF,     claim: NO_PILOT,  writes: NO_PILOT},
        {what: 'own row, refiled elsewhere',    owner: SELF,     claim: OTHER,     denies: /refile/},

        {what: 'maintenance row, unclaimed',    owner: NO_PILOT, claim: undefined, writes: NO_PILOT},
        {what: 'maintenance row, reaffirmed',   owner: NO_PILOT, claim: ' no pilot ', writes: NO_PILOT},
        {what: 'maintenance row, claimed back', owner: NO_PILOT, claim: SELF,      denies: /take over/},
        {what: 'maintenance row, given away',   owner: NO_PILOT, claim: OTHER,     denies: /take over/},

        {what: 'another\'s row, unclaimed',     owner: OTHER,    claim: undefined, denies: /another name/},
        {what: 'another\'s row, claimed',       owner: OTHER,    claim: SELF,      denies: /another name/},
        {what: 'another\'s row, handed over',   owner: OTHER,    claim: NO_PILOT,  denies: /another name/},
        {what: 'another\'s row, left alone',    owner: OTHER,    claim: OTHER,     denies: /another name/},

        {what: 'unowned row, unclaimed',        owner: '',       claim: undefined, denies: /another name/},
        {what: 'unowned row, claimed',          owner: '',       claim: SELF,      denies: /another name/}
    ];

    for (const row of MATRIX) {
        it(row.what + (row.writes ? ' → ' + row.writes : ' → refused'), () => {
            const result = resolveIdentityForUpdate(
                flight_log_config, claiming(row.claim), pilot(), rowFiledUnder(row.owner)
            );
            if (row.writes) {
                assertWrites(result, row.writes);
            } else {
                assertDenied(result, row.denies);
            }
        });
    }

    it('never names the owner of a row the caller may not touch', () => {
        // Who flew what is not something a refusal should hand out to whoever
        // guesses an id.
        const result = resolveIdentityForUpdate(
            flight_log_config, claiming(SELF), pilot(), rowFiledUnder(OTHER)
        );
        assert.doesNotMatch(result.error, new RegExp(OTHER));
    });

    it('rejects a non-string claim before reading the row', () => {
        assertDenied(
            resolveIdentityForUpdate(flight_log_config, claiming(42), pilot(), rowFiledUnder(SELF)),
            /must be a string/,
            ERROR.BAD_REQUEST
        );
    });
});

describe('delete', () => {
    it('allows a pilot to remove their own entry', () => {
        assert.equal(checkIdentityForDelete(flight_log_config, pilot(), rowFiledUnder('  bOb ')), null);
    });

    it('refuses another pilot\'s entry', () => {
        assert.match(
            checkIdentityForDelete(flight_log_config, pilot(), rowFiledUnder(OTHER)),
            /another name/
        );
    });

    it('allows a maintenance entry, exactly as update does', () => {
        // The two actions answer the same ownership question. Asserted side by
        // side on purpose: this is what fails if one of the two checks is ever
        // changed without the other.
        assert.equal(
            resolveIdentityForUpdate(flight_log_config, claiming(undefined), pilot(), rowFiledUnder(NO_PILOT)).error,
            undefined
        );
        assert.equal(
            checkIdentityForDelete(flight_log_config, pilot(), rowFiledUnder(NO_PILOT)),
            null
        );
    });

    it('refuses an unowned entry', () => {
        assert.match(
            checkIdentityForDelete(flight_log_config, pilot(), rowFiledUnder('')),
            /another name/
        );
    });
});

describe('admin', () => {
    for (const owner of [SELF, OTHER, NO_PILOT, '']) {
        it('updates a row filed under "' + owner + '"', () => {
            assertWrites(
                resolveIdentityForUpdate(flight_log_config, claiming(OTHER), admin(), rowFiledUnder(owner)),
                OTHER
            );
        });

        it('deletes a row filed under "' + owner + '"', () => {
            assert.equal(checkIdentityForDelete(flight_log_config, admin(), rowFiledUnder(owner)), null);
        });
    }

    it('leaves a row where it is when claiming nothing', () => {
        assertWrites(
            resolveIdentityForUpdate(flight_log_config, claiming(undefined), admin(), rowFiledUnder(OTHER)),
            OTHER
        );
    });
});

describe('without a maintenance name configured', () => {
    beforeEach(() => {
        setScriptProperties({});
    });

    it('reports no maintenance name', () => {
        assert.equal(getNoPilotName(), null);
    });

    it('treats the maintenance name as any other pilot on insert', () => {
        assertDenied(resolveIdentityForInsert(flight_log_config, claiming(NO_PILOT), pilot()), /add entry as/);
    });

    it('treats the maintenance name as any other pilot on update', () => {
        assertDenied(
            resolveIdentityForUpdate(flight_log_config, claiming(NO_PILOT), pilot(), rowFiledUnder(SELF)),
            /refile/
        );
    });

    it('leaves a row already filed under it out of reach', () => {
        assertDenied(
            resolveIdentityForUpdate(flight_log_config, claiming(undefined), pilot(), rowFiledUnder(NO_PILOT)),
            /another name/
        );
    });

    it('leaves a row already filed under it undeletable too', () => {
        // The exemption is granted by the configured name, not by the string:
        // without `NO_PILOT_NAME` the row belongs to a pilot nobody is.
        assert.match(
            checkIdentityForDelete(flight_log_config, pilot(), rowFiledUnder(NO_PILOT)),
            /another name/
        );
    });

    it('does not hand an unowned row to everybody', () => {
        // `sameName('', null)` is true: an empty cell and an unconfigured
        // maintenance name normalize to the same empty string. Both resolvers
        // therefore test that a name is configured *before* comparing against
        // it. Drop that test and every row with a blank pilot column becomes
        // editable and deletable by any pilot who can guess its id.
        assertDenied(
            resolveIdentityForUpdate(flight_log_config, claiming(undefined), pilot(), rowFiledUnder('')),
            /another name/
        );
        assert.match(
            checkIdentityForDelete(flight_log_config, pilot(), rowFiledUnder('')),
            /another name/
        );
    });

    it('still lets a pilot work on their own rows', () => {
        assertWrites(resolveIdentityForInsert(flight_log_config, claiming(undefined), pilot()), SELF);
    });
});

describe('a name that is not text', () => {
    // Sheets hands back a number or a Date for a cell it decided to reinterpret.
    // Such a row matches nobody, so it is admin territory — never a coincidence
    // that lets the wrong caller through.
    for (const owner of [12345, new Date(2026, 0, 1), true]) {
        it('is owned by nobody: ' + String(owner), () => {
            assertDenied(
                resolveIdentityForUpdate(flight_log_config, claiming(undefined), pilot(), rowFiledUnder(owner)),
                /another name/
            );
            assert.match(
                checkIdentityForDelete(flight_log_config, pilot(), rowFiledUnder(owner)),
                /another name/
            );
        });
    }
});
