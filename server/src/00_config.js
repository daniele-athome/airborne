/**
 * Airborne backend — configuration.
 *
 * Nothing secret lives in this file: sheet names and the token salt are read
 * from the script properties (Project Settings > Script Properties in the Apps
 * Script editor). See README.md for the full list.
 *
 * There are no spreadsheet ids: this script is bound to the spreadsheet it
 * serves and can only reach that one.
 */

/** Protocol contract version spoken by this build. */
const PROTOCOL_V = 1;

/** Oldest protocol version still accepted. */
const PROTOCOL_V_MIN = 1;

/** Newest protocol version accepted. */
const PROTOCOL_V_MAX = 1;

/** Overridden by the generated 01_build.js at deploy time. */
let BUILD_ID = 'dev';

/** How long an idempotency record is kept, in seconds (the cache allows up to 6h). */
const IDEMPOTENCY_TTL_SECONDS = 180;

/** How long to wait for the script lock before giving up. */
const LOCK_TIMEOUT_MS = 20000;

/**
 * Reads a script property.
 *
 * Throws when a required property is missing: a misconfigured deployment must
 * fail loudly at the first request, not silently write to the wrong place.
 */
function getProperty(key, required) {
    const value = PropertiesService.getScriptProperties().getProperty(key);
    if ((value === null || value === '') && required) {
        throw new Error('Missing script property: ' + key);
    }
    return value;
}
