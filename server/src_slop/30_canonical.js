/**
 * Airborne backend — row canonicalization and fingerprints.
 *
 * The fingerprint is a precondition token for update/delete: the client stores
 * it next to the item and echoes it back, and the server recomputes it from the
 * current row inside the lock. It is deliberately computed over the *whole*
 * row, including columns the app does not map, so that an edit made by hand in
 * the spreadsheet is detected just like a concurrent edit from another client.
 *
 * This file must stay free of Apps Script services other than `Utilities`, so
 * the canonicalization can be unit tested outside the Google runtime.
 *
 * Changing anything here invalidates every fingerprint clients currently hold
 * and produces a one-off wave of spurious conflicts. Do it deliberately.
 */

/** Field separator: the ASCII unit separator, which cannot occur in sheet content. */
var CANONICAL_SEPARATOR = '\u001F';

/**
 * Normalizes a single cell value to a stable string.
 *
 * Empty, null and undefined collapse to the same thing because Sheets truncates
 * trailing empty cells: `[a, b, '']` and `[a, b]` are the same row.
 */
function canonicalizeValue(value) {
  if (value === null || value === undefined || value === '') {
    return '';
  }
  if (value instanceof Date) {
    return 'd:' + value.getTime();
  }
  if (typeof value === 'number') {
    // String(Number) already collapses 1247.30 and 1247.3 to the same text.
    return isFinite(value) ? 'n:' + String(value) : '';
  }
  if (typeof value === 'boolean') {
    return 'b:' + (value ? '1' : '0');
  }
  // Strings are kept verbatim: a trailing space in a note is a real difference.
  return 's:' + String(value);
}

/**
 * Builds the canonical representation of a row.
 *
 * `columnCount` pads the row to its declared width so that trailing empty cells
 * cannot change the result.
 */
function canonicalizeRow(values, columnCount) {
  var parts = [];
  for (var i = 0; i < columnCount; i++) {
    parts.push(canonicalizeValue(i < values.length ? values[i] : ''));
  }
  return parts.join(CANONICAL_SEPARATOR);
}

/**
 * Computes the fingerprint of a row.
 *
 * Truncation is safe: this is not a security boundary — anyone holding a valid
 * token can read the current fingerprint with `list` — it only has to make
 * accidental collisions between two concurrent edits of the same row
 * implausible.
 */
function fingerprintRow(values, columnCount) {
  var canonical = canonicalizeRow(values, columnCount);
  var digest = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, canonical);
  return toHex(digest).substring(0, FINGERPRINT_LENGTH);
}
