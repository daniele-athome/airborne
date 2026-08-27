/**
 * Token resolution.
 *
 * `authenticate` is the whole of the front door: everything downstream trusts
 * the `{pilotName, role}` it hands back, and the identity layer compares names
 * against `pilotName` to decide who may touch which row. So the cases that
 * matter here are the ones where a lookup quietly does not find what an operator
 * meant to write in the sheet — a token that matches when it should not, or a
 * role that fails to attach.
 *
 * A token alone is not enough: a pilot with no role configured is refused. Both
 * halves of the pair have to be written down, which means the sheet says who may
 * come in rather than leaving it implied by the presence of a secret.
 *
 * Metadata arrives from `readMetadata`, which stringifies every cell, so the
 * fixtures here are objects of strings.
 */

const {describe, it} = require('node:test');
const assert = require('node:assert/strict');

require('./load.js');

const TOKEN = 'af71c0e2';

/** The metadata of a club with one pilot and one admin, both fully configured. */
function club(extra) {
    return Object.assign({
        'flight_log.hash': '17',
        'token.Bob': TOKEN,
        'role.Bob': 'pilot',
        'token.Alice': 'b0b0b0b0',
        'role.Alice': 'admin'
    }, extra);
}

/** The same club with one of its keys removed. */
function clubWithout(key) {
    const metadata = club();
    delete metadata[key];
    return metadata;
}

/** Bob's role, filed under `key` instead of the usual `role.Bob`. */
function withRole(key, value) {
    const metadata = clubWithout('role.Bob');
    metadata[key] = value;
    return authenticate(TOKEN, metadata);
}

function assertIdentity(identity, pilotName, role) {
    assert.notEqual(identity, null, 'expected a match');
    assert.equal(identity.pilotName, pilotName);
    assert.equal(identity.role, role);
}

describe('authenticate', () => {
    it('finds nothing in an empty store', () => {
        assert.equal(authenticate(TOKEN, {}), null);
    });

    it('finds nothing for an unknown token', () => {
        assert.equal(authenticate('nope', club()), null);
    });

    it('resolves a token to its pilot', () => {
        assertIdentity(authenticate(TOKEN, club()), 'Bob', ROLE_PILOT);
    });

    it('picks the right pilot when several are configured', () => {
        assertIdentity(authenticate('b0b0b0b0', club()), 'Alice', ROLE_ADMIN);
    });

    it('lowercases the role it reads', () => {
        assertIdentity(authenticate(TOKEN, club({'role.Bob': 'Admin'})), 'Bob', ROLE_ADMIN);
    });

    it('ignores keys that are not tokens', () => {
        assert.equal(authenticate('17', club()), null);
    });

    it('requires the prefix at the start of the key', () => {
        assert.equal(authenticate('xyz', {'my.token.Bob': 'xyz', 'role.Bob': 'pilot'}), null);
    });

    it('skips a token key with no name after it', () => {
        // A bare `token.` would otherwise authenticate to the empty name, and an
        // empty name is what a row with a blank pilot column looks like.
        assert.equal(authenticate('xyz', {'token.': 'xyz', 'role.': 'pilot'}), null);
    });

    it('skips an empty token cell', () => {
        // Otherwise every request without a token would match the empty cell.
        assert.equal(authenticate('', {'token.Bob': '', 'role.Bob': 'pilot'}), null);
    });

    it('trims the name it takes from the key', () => {
        assertIdentity(authenticate(TOKEN, {'token.Bob ': TOKEN, 'role.Bob': 'pilot'}), 'Bob', ROLE_PILOT);
    });

    it('tolerates whitespace around the token on both sides', () => {
        assertIdentity(authenticate('  ' + TOKEN + '  ', club()), 'Bob', ROLE_PILOT);
        assertIdentity(authenticate(TOKEN, club({'token.Bob': ' ' + TOKEN + ' '})), 'Bob', ROLE_PILOT);
    });

    it('does not ignore case in the token', () => {
        // Deliberate: a token is a secret, not a name. Pinned so that adding a
        // `toLowerCase()` here — which would look like a kindness — has to be a
        // decision rather than an accident.
        assert.equal(authenticate(TOKEN.toUpperCase(), club()), null);
    });

    it('keeps looking past a key that does not match', () => {
        const metadata = club({'token.Zoe': '', 'token.Yuri': 'other'});
        assertIdentity(authenticate(TOKEN, metadata), 'Bob', ROLE_PILOT);
    });

    it('returns the first key when two share a token', () => {
        // A misconfiguration with no right answer; pinned so the behaviour is at
        // least known. Insertion order is what Object.keys gives for string keys.
        const metadata = {'token.Bob': TOKEN, 'role.Bob': 'pilot', 'token.Alice': TOKEN, 'role.Alice': 'admin'};
        assertIdentity(authenticate(TOKEN, metadata), 'Bob', ROLE_PILOT);
    });

    /*
     * `parseEnvelope` rejects only the exactly empty token, so a request carrying
     * `"token": "   "` reaches this function. Both sides trim to the empty
     * string, and without a guard they compare equal: a metadata cell holding
     * nothing but spaces would authenticate as its pilot, and the request that
     * got in would carry no secret at all. Someone hitting the space bar while
     * clearing a revoked token is enough to leave that cell behind.
     */
    it('refuses a blank token against a cell of blanks', () => {
        assert.equal(authenticate('   ', {'token.Bob': '   ', 'role.Bob': 'pilot'}), null);
        assert.equal(authenticate('', {'token.Bob': ' ', 'role.Bob': 'pilot'}), null);
        assert.equal(authenticate('\t\n', {'token.Bob': ' \t ', 'role.Bob': 'pilot'}), null);
    });

    /*
     * The role must be found under the name however it was spelled: every name
     * comparison downstream ignores case, and a sheet whose two halves disagree
     * about it is the mistake a human makes. An exact lookup would find nothing,
     * and now that a missing role refuses the request outright, that mistake
     * locks a pilot out rather than merely demoting them.
     */
    it('finds the role whatever case it was written in', () => {
        assertIdentity(withRole('role.bob', 'admin'), 'Bob', ROLE_ADMIN);
        assertIdentity(withRole('role.BOB', 'admin'), 'Bob', ROLE_ADMIN);
    });

    it('tolerates whitespace around the role', () => {
        assertIdentity(authenticate(TOKEN, club({'role.Bob': ' admin '})), 'Bob', ROLE_ADMIN);
        assertIdentity(withRole('role. Bob ', 'admin'), 'Bob', ROLE_ADMIN);
    });
});

describe('authenticate: a token is not enough on its own', () => {
    it('refuses a pilot with no role configured', () => {
        // The sheet has to say who may come in. A token left behind in a column
        // nobody prunes does not, by itself, admit anyone.
        assert.equal(authenticate(TOKEN, clubWithout('role.Bob')), null);
    });

    it('refuses a pilot whose role cell is blank', () => {
        assert.equal(authenticate(TOKEN, club({'role.Bob': ''})), null);
        assert.equal(authenticate(TOKEN, club({'role.Bob': '   '})), null);
    });

    it('refuses when the only role key names somebody else', () => {
        assert.equal(withRole('role.Roberta', 'admin'), null);
    });

    it('ignores a role key with no name after it', () => {
        assert.equal(withRole('role.', 'admin'), null);
    });

    it('keeps looking when the matched pilot has no role', () => {
        // Two keys carrying the same token, the first of them unconfigured: the
        // loop moves on rather than refusing outright, so the configured pilot
        // still gets in.
        const metadata = {'token.Zoe': TOKEN, 'token.Bob': TOKEN, 'role.Bob': 'admin'};
        assertIdentity(authenticate(TOKEN, metadata), 'Bob', ROLE_ADMIN);
    });

    it('accepts any non-empty role, recognized or not', () => {
        // Documented, not endorsed: the check is "a role is written down", not
        // "the role is one we know". A typo like `piolt` lets its pilot in as a
        // non-admin, which is the safe direction but not an obvious one.
        assertIdentity(authenticate(TOKEN, club({'role.Bob': 'piolt'})), 'Bob', 'piolt');
    });
});

describe('findRole', () => {
    it('reports no role rather than assuming one', () => {
        assert.equal(findRole('Bob', {}), null);
        assert.equal(findRole('Bob', {'role.Alice': 'admin'}), null);
        assert.equal(findRole('Bob', {'role.Bob': '  '}), null);
    });

    it('normalizes both the name and the value', () => {
        assert.equal(findRole('Bob', {'role.BOB': ' Admin '}), ROLE_ADMIN);
        assert.equal(findRole('  bob  ', {'role.Bob': 'pilot'}), ROLE_PILOT);
    });

    it('skips a blank role and keeps looking', () => {
        assert.equal(findRole('Bob', {'role.Bob': '', 'role.bob': 'admin'}), ROLE_ADMIN);
    });
});

describe('isAdmin', () => {
    it('recognizes the admin role', () => {
        assert.equal(isAdmin({pilotName: 'Alice', role: ROLE_ADMIN}), true);
    });

    it('rejects every other role', () => {
        assert.equal(isAdmin({pilotName: 'Bob', role: ROLE_PILOT}), false);
        assert.equal(isAdmin({pilotName: 'Bob', role: 'owner'}), false);
        assert.equal(isAdmin({pilotName: 'Bob', role: ''}), false);
    });

    it('expects a role already normalized', () => {
        // It compares exactly, so it depends on `authenticate` having lowercased
        // first. Anything building an identity by hand must do the same.
        assert.equal(isAdmin({pilotName: 'Alice', role: 'ADMIN'}), false);
    });
});
