/** Metadata key prefix for tokens. */
const TOKEN_KEY_PREFIX = 'token.';

/** Metadata key prefix for pilot roles. */
const ROLE_KEY_PREFIX = 'role.';

const ROLE_ADMIN = 'admin';
const ROLE_PILOT = 'pilot';

/**
 * Trims a value coming from a cell or from a request.
 *
 * Absence and a cell Sheets decided to read as a number both become text, so
 * that everything downstream compares strings and nothing else.
 */
function normalizeName(value) {
    if (value === null || value === undefined) {
        return '';
    }
    return String(value).trim();
}

/** Safe comparison of two names. */
function sameName(a, b) {
    return normalizeName(a).toLowerCase() === normalizeName(b).toLowerCase();
}

function findRole(pilotName, metadata) {
    const keys = Object.keys(metadata);

    for (let i = 0; i < keys.length; i++) {
        const key = keys[i];
        if (key.indexOf(ROLE_KEY_PREFIX) !== 0) {
            continue;
        }
        if (!sameName(key.substring(ROLE_KEY_PREFIX.length), pilotName)) {
            continue;
        }
        const role = normalizeName(metadata[key]).toLowerCase();
        if (role !== '') {
            return role;
        }
    }

    // no role - not authorized
    return null;
}

/**
 * Resolves a token to its pilot.
 * Returns `{ pilotName, role }`, or null when the token matches nothing.
 */
function authenticate(token, metadata) {
    const keys = Object.keys(metadata);

    for (let i = 0; i < keys.length; i++) {
        const key = keys[i];
        if (key.indexOf(TOKEN_KEY_PREFIX) !== 0) {
            continue;
        }
        const secret = normalizeName(metadata[key]);
        if (secret === '' || secret !== normalizeName(token)) {
            continue;
        }
        const pilotName = key.substring(TOKEN_KEY_PREFIX.length).trim();
        if (pilotName === '') {
            // configuration error
            continue;
        }
        const role = findRole(pilotName, metadata);
        if (role) {
            return {pilotName: pilotName, role: role};
        }
    }

    return null;
}

function isAdmin(identity) {
    return identity.role === ROLE_ADMIN;
}

/* Test-only: see test/load.js. Apps Script has no `module`, so this never runs there. */
if (typeof module === 'object') {
    module.exports = {
        TOKEN_KEY_PREFIX, ROLE_KEY_PREFIX, ROLE_ADMIN, ROLE_PILOT,
        normalizeName, sameName, findRole, authenticate, isAdmin
    };
}
