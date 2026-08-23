/**
 * Airborne backend — authentication.
 *
 * Tokens live in the metadata sheet as `token.<pilot_name>` keys, and the sheet
 * stores the *hash* of the token, never the token itself: the metadata sheet is
 * read wholesale by the app and ends up in its logs, so a plaintext token there
 * would be readable by every client and by anyone reading a log file.
 */

/** Metadata key prefix for token hashes. */
var TOKEN_KEY_PREFIX = 'token.';

/** Metadata key prefix for pilot roles. */
var ROLE_KEY_PREFIX = 'role.';

var ROLE_ADMIN = 'admin';
var ROLE_PILOT = 'pilot';

/**
 * Hashes a token with the deployment salt.
 *
 * The salt lives in the script properties, so leaking the sheet is not enough
 * to precompute hashes offline.
 */
function hashToken(token) {
  var salt = getProperty('TOKEN_SALT', true);
  return toHex(Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, salt + '' + token));
}

/** Converts a signed byte array as returned by `computeDigest` to lowercase hex. */
function toHex(bytes) {
  var hex = '';
  for (var i = 0; i < bytes.length; i++) {
    var b = (bytes[i] + 256) % 256;
    hex += (b < 16 ? '0' : '') + b.toString(16);
  }
  return hex;
}

/**
 * Resolves a token to its pilot.
 *
 * Returns `{ pilotName, role }`, or null when the token matches nothing.
 * Revocation is simply the removal of the metadata row.
 */
function authenticate(token, metadata) {
  var expected = hashToken(token);
  var keys = Object.keys(metadata);

  for (var i = 0; i < keys.length; i++) {
    var key = keys[i];
    if (key.indexOf(TOKEN_KEY_PREFIX) !== 0) {
      continue;
    }
    var value = metadata[key];
    if (!value || !constantTimeEquals(value.toLowerCase(), expected)) {
      continue;
    }
    var pilotName = key.substring(TOKEN_KEY_PREFIX.length);
    var role = metadata[ROLE_KEY_PREFIX + pilotName] || ROLE_PILOT;
    return { pilotName: pilotName, role: role.toLowerCase() };
  }

  return null;
}

/**
 * Compares two strings without an early exit.
 *
 * The timing of a sheet lookup dwarfs any leak this prevents, but the habit
 * costs nothing and keeps the comparison from being copied elsewhere in a
 * weaker form.
 */
function constantTimeEquals(a, b) {
  if (a.length !== b.length) {
    return false;
  }
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

function isAdmin(identity) {
  return identity.role === ROLE_ADMIN;
}
