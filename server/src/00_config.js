/**
 * Airborne backend — configuration.
 *
 * Nothing secret lives in this file: spreadsheet ids, sheet names and the token
 * salt are read from the script properties (Project Settings > Script
 * Properties in the Apps Script editor). See README.md for the full list.
 */

/** Protocol contract version spoken by this build. */
var PROTOCOL_V = 1;

/** Oldest protocol version still accepted. */
var PROTOCOL_V_MIN = 1;

/** Newest protocol version accepted. */
var PROTOCOL_V_MAX = 1;

/** Overridden by the generated 01_build.js at deploy time. */
var BUILD_ID = 'dev';

/** How long an idempotency record is kept, in seconds (6h is the cache maximum). */
var IDEMPOTENCY_TTL_SECONDS = 21600;

/** How long to wait for the script lock before giving up. */
var LOCK_TIMEOUT_MS = 20000;

/** Backoff hint returned to the client when the lock could not be acquired. */
var LOCK_RETRY_AFTER_MS = 1500;

/** Page size used by `list` when the client does not ask for one. */
var DEFAULT_PAGE_SIZE = 20;

/** Upper bound on the page size a client may ask for. */
var MAX_PAGE_SIZE = 100;

/** Length of the truncated fingerprint, in hex characters. */
var FINGERPRINT_LENGTH = 12;

/**
 * Store definitions.
 *
 * `fields` maps payload field names to column indexes (0-based). The mapping is
 * authoritative: clients never send positional data, so columns can be
 * reordered here without a protocol change as long as the sheet is migrated
 * accordingly.
 *
 * Field flags:
 *  - `required`  the payload must carry it on insert
 *  - `nullable`  an empty value is allowed and stored as an empty cell
 *  - `identity`  filled from the authenticated pilot, not from the payload
 *                (an admin token may override it)
 *  - `managed`   filled by the server, never taken from the payload
 *  - `immutable` set on insert, preserved as-is on update
 *
 * Columns not listed are preserved verbatim on update: the sheet may carry
 * extra columns this build knows nothing about.
 */
var STORES = {
  flight_log: {
    metadataPrefix: 'flight_log',
    spreadsheetIdProperty: 'FLIGHT_LOG_SPREADSHEET_ID',
    sheetNameProperty: 'FLIGHT_LOG_SHEET_NAME',
    headerRows: 1,
    columnCount: 10,
    // 'row'    : item id is the 1-based ordinal of the data row (legacy)
    // 'column' : item id is read from `idColumnIndex` (stable across deletions)
    idStrategy: 'row',
    idColumnIndex: null,
    fields: [
      { name: 'createdAt', index: 0, type: 'date', managed: 'createdAt', immutable: true },
      { name: 'date', index: 1, type: 'date', required: true },
      { name: 'pilotName', index: 2, type: 'string', required: true, identity: true },
      { name: 'startHour', index: 3, type: 'number', required: true },
      { name: 'endHour', index: 4, type: 'number', required: true },
      { name: 'origin', index: 5, type: 'string', required: true },
      { name: 'destination', index: 6, type: 'string', required: true },
      { name: 'fuel', index: 7, type: 'number', nullable: true },
      { name: 'fuelPrice', index: 8, type: 'number', nullable: true },
      { name: 'notes', index: 9, type: 'string', nullable: true }
    ]
  },

  activities: {
    metadataPrefix: 'activities',
    spreadsheetIdProperty: 'ACTIVITIES_SPREADSHEET_ID',
    sheetNameProperty: 'ACTIVITIES_SHEET_NAME',
    headerRows: 1,
    columnCount: 10,
    idStrategy: 'row',
    idColumnIndex: null,
    fields: [
      { name: 'createdAt', index: 0, type: 'date', managed: 'createdAt', immutable: true },
      { name: 'creationDate', index: 1, type: 'date', managed: 'createdAt', immutable: true },
      { name: 'type', index: 2, type: 'integer', required: true, values: [10, 30, 70, 90, 100] },
      { name: 'status', index: 3, type: 'string', nullable: true, values: ['TODO', 'IN PROGRESS', 'DONE'] },
      { name: 'lastStatusUpdate', index: 4, type: 'date', managed: 'statusTimestamp' },
      { name: 'dueDate', index: 5, type: 'date', nullable: true },
      { name: 'author', index: 6, type: 'string', required: true, identity: true },
      { name: 'summary', index: 7, type: 'string', required: true },
      { name: 'description', index: 8, type: 'string', nullable: true }
      // index 9 is reserved for the alert flag, which the app does not model
      // yet: it is left untouched by insert and preserved on update.
    ]
  }
};

/** Returns the store definition, or null if the name is unknown. */
function getStoreConfig(name) {
  return Object.prototype.hasOwnProperty.call(STORES, name) ? STORES[name] : null;
}

/** Returns the field definition of `store` named `name`, or null. */
function getFieldConfig(storeConfig, name) {
  for (var i = 0; i < storeConfig.fields.length; i++) {
    if (storeConfig.fields[i].name === name) {
      return storeConfig.fields[i];
    }
  }
  return null;
}

/**
 * Reads a script property.
 *
 * Throws when a required property is missing: a misconfigured deployment must
 * fail loudly at the first request, not silently write to the wrong place.
 */
function getProperty(key, required) {
  var value = PropertiesService.getScriptProperties().getProperty(key);
  if ((value === null || value === '') && required) {
    throw new Error('Missing script property: ' + key);
  }
  return value;
}
