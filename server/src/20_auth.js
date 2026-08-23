const ROLE_ADMIN = 'admin';
const ROLE_PILOT = 'pilot';

/**
 * Resolves a token to its pilot.
 * Returns `{ pilotName, role }`, or null when the token matches nothing.
 */
function authenticate(token) {
    const adminToken = getProperty("TOKEN_ADMIN", true);
    if (token === adminToken) {
        return {pilotName: 'admin', role: 'admin'};
    }

    const pilotToken = getProperty("TOKEN_PILOT", true);
    if (token === pilotToken) {
        return {pilotName: 'pilot', role: 'pilot'};
    }

    return null;
}

function isAdmin(identity) {
    return identity.role === ROLE_ADMIN;
}
