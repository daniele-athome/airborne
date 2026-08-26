/** Metadata key prefix for tokens. */
const TOKEN_KEY_PREFIX = 'token.';

/** Metadata key prefix for pilot roles. */
const ROLE_KEY_PREFIX = 'role.';

const ROLE_ADMIN = 'admin';
const ROLE_PILOT = 'pilot';

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
        const value = metadata[key];
        if (!value || String(value).trim() !== String(token).trim()) {
            continue;
        }
        const pilotName = key.substring(TOKEN_KEY_PREFIX.length).trim();
        if (pilotName === '') {
            // configuration error
            continue;
        }
        const role = metadata[ROLE_KEY_PREFIX + pilotName] || ROLE_PILOT;
        return { pilotName: pilotName, role: role.toLowerCase() };
    }

    return null;
}

function isAdmin(identity) {
    return identity.role === ROLE_ADMIN;
}
