/**
 * Airborne backend — sheet access.
 *
 * Every read and write of the data sheets and of the metadata key-value sheet
 * goes through here. Callers are expected to already hold the script lock for
 * anything that mutates.
 *
 * This is a container-bound script: everything it touches lives in the
 * spreadsheet it is attached to, reached through `getActive()`. There is no
 * `openById` anywhere, and the manifest asks only for
 * `spreadsheets.currentonly`, so the deployment cannot reach any other
 * spreadsheet of the owner even though it runs with the owner's identity.
 */

/** Data range of the metadata key-value store, matching the app's own range. */
var METADATA_FIRST_ROW = 2;

/** Returns a sheet of the container spreadsheet, or throws if it is missing. */
function openSheetByName(sheetName, what) {
  var sheet = SpreadsheetApp.getActive().getSheetByName(sheetName);
  if (!sheet) {
    throw new Error(what + ' sheet not found in this spreadsheet: ' + sheetName);
  }
  return sheet;
}

/** Opens the sheet backing a store, throwing when the deployment is misconfigured. */
function openStoreSheet(storeConfig) {
  return openSheetByName(getProperty(storeConfig.sheetNameProperty, true), storeConfig.metadataPrefix);
}

function openMetadataSheet() {
  return openSheetByName(getProperty('METADATA_SHEET_NAME', true), 'Metadata');
}

/** Reads the whole metadata key-value store as a plain object. */
function readMetadata() {
  var sheet = openMetadataSheet();
  var lastRow = sheet.getLastRow();
  var store = {};
  if (lastRow < METADATA_FIRST_ROW) {
    return store;
  }
  var values = sheet.getRange(METADATA_FIRST_ROW, 1, lastRow - METADATA_FIRST_ROW + 1, 2).getValues();
  for (var i = 0; i < values.length; i++) {
    var key = values[i][0];
    if (key !== null && key !== undefined && key !== '') {
      store[String(key)] = values[i][1] === null || values[i][1] === undefined ? '' : String(values[i][1]);
    }
  }
  return store;
}

/** Writes a metadata value, appending the key when it does not exist yet. */
function writeMetadata(key, value) {
  var sheet = openMetadataSheet();
  var lastRow = sheet.getLastRow();
  if (lastRow >= METADATA_FIRST_ROW) {
    var keys = sheet.getRange(METADATA_FIRST_ROW, 1, lastRow - METADATA_FIRST_ROW + 1, 1).getValues();
    for (var i = 0; i < keys.length; i++) {
      if (String(keys[i][0]) === key) {
        sheet.getRange(METADATA_FIRST_ROW + i, 2).setValue(value);
        return;
      }
    }
  }
  sheet.appendRow([key, value]);
}

function versionKey(storeConfig) {
  return storeConfig.metadataPrefix + '.hash';
}

function countKey(storeConfig) {
  return storeConfig.metadataPrefix + '.count';
}

function nextIdKey(storeConfig) {
  return storeConfig.metadataPrefix + '.next_id';
}

/**
 * Bumps the store version and returns the new value.
 *
 * The app only ever compares this value for equality, so a monotonic counter is
 * enough. A non-numeric legacy value restarts the count rather than failing:
 * the app will see a change, which is exactly the correct outcome.
 */
function bumpVersion(storeConfig, metadata) {
  var current = parseInt(metadata[versionKey(storeConfig)], 10);
  var next = (isNaN(current) ? 0 : current) + 1;
  writeMetadata(versionKey(storeConfig), String(next));
  return String(next);
}

/**
 * Number of data rows currently in the sheet.
 *
 * Derived from the sheet rather than from the metadata counter, because a row
 * added by hand in the browser never touches the counter.
 */
function getRowCount(sheet, storeConfig) {
  return Math.max(0, sheet.getLastRow() - storeConfig.headerRows);
}

/** Converts a 1-based data ordinal to a sheet row number. */
function ordinalToRow(storeConfig, ordinal) {
  return ordinal + storeConfig.headerRows;
}

/** Reads a contiguous block of data rows, padded to the declared column count. */
function readRows(sheet, storeConfig, firstOrdinal, lastOrdinal) {
  if (lastOrdinal < firstOrdinal) {
    return [];
  }
  var values = sheet
    .getRange(
      ordinalToRow(storeConfig, firstOrdinal),
      1,
      lastOrdinal - firstOrdinal + 1,
      storeConfig.columnCount
    )
    .getValues();
  return values;
}

/** Reads a single data row, or null when the ordinal is out of range. */
function readRow(sheet, storeConfig, ordinal) {
  if (ordinal < 1 || ordinal > getRowCount(sheet, storeConfig)) {
    return null;
  }
  var rows = readRows(sheet, storeConfig, ordinal, ordinal);
  return rows.length ? rows[0] : null;
}

function writeRow(sheet, storeConfig, ordinal, values) {
  sheet
    .getRange(ordinalToRow(storeConfig, ordinal), 1, 1, storeConfig.columnCount)
    .setValues([values]);
}

function appendRow(sheet, storeConfig, values) {
  var ordinal = getRowCount(sheet, storeConfig) + 1;
  writeRow(sheet, storeConfig, ordinal, values);
  return ordinal;
}

function deleteRow(sheet, storeConfig, ordinal) {
  sheet.deleteRow(ordinalToRow(storeConfig, ordinal));
}

/**
 * Returns the item id of a data row.
 *
 * With the `row` strategy the id is the ordinal itself, which is what the app
 * has always used; with the `column` strategy it is read from the id column and
 * survives insertions and deletions above it.
 */
function idForRow(storeConfig, ordinal, values) {
  if (storeConfig.idStrategy === 'column') {
    var raw = values[storeConfig.idColumnIndex];
    return raw === null || raw === undefined || raw === '' ? null : String(raw);
  }
  return String(ordinal);
}

/**
 * Resolves an item id to its data ordinal, or -1 when it no longer exists.
 *
 * A missing row is not the same as a stale fingerprint: the caller reports
 * NOT_FOUND, so the app can say "someone deleted this entry" rather than
 * "someone modified it".
 */
function resolveOrdinal(sheet, storeConfig, id) {
  var count = getRowCount(sheet, storeConfig);

  if (storeConfig.idStrategy === 'column') {
    if (count === 0) {
      return -1;
    }
    var column = sheet
      .getRange(ordinalToRow(storeConfig, 1), storeConfig.idColumnIndex + 1, count, 1)
      .getValues();
    for (var i = 0; i < column.length; i++) {
      if (String(column[i][0]) === id) {
        return i + 1;
      }
    }
    return -1;
  }

  var ordinal = parseInt(id, 10);
  if (isNaN(ordinal) || ordinal < 1 || ordinal > count) {
    return -1;
  }
  return ordinal;
}

/** Allocates the next stable id. Only used by the `column` strategy. */
function allocateId(storeConfig, metadata) {
  var current = parseInt(metadata[nextIdKey(storeConfig)], 10);
  var next = isNaN(current) ? 1 : current;
  writeMetadata(nextIdKey(storeConfig), String(next + 1));
  return String(next);
}

/** Builds the wire representation of a data row. */
function rowToItem(storeConfig, ordinal, values) {
  var item = {
    id: idForRow(storeConfig, ordinal, values),
    fingerprint: fingerprintRow(values, storeConfig.columnCount)
  };
  for (var i = 0; i < storeConfig.fields.length; i++) {
    var field = storeConfig.fields[i];
    item[field.name] = serializeValue(field, values[field.index]);
  }
  return item;
}

/** Converts a cell value to its JSON representation. */
function serializeValue(field, value) {
  if (value === null || value === undefined || value === '') {
    return null;
  }
  if (field.type === 'date') {
    return value instanceof Date ? Utilities.formatDate(value, Session.getScriptTimeZone(), "yyyy-MM-dd'T'HH:mm:ss") : String(value);
  }
  if (field.type === 'number' || field.type === 'integer') {
    return typeof value === 'number' ? value : Number(value);
  }
  return String(value);
}

/**
 * Reads the state block returned with every response for a single store.
 *
 * `countOverride` is used right after a write, where the caller already knows
 * the resulting count and should not depend on the sheet reflecting a pending
 * change before the flush.
 */
function stateFor(storeConfig, sheet, metadata, countOverride) {
  var state = {};
  state[storeConfig.metadataPrefix] = {
    hash: metadata[versionKey(storeConfig)] || null,
    count: countOverride === undefined ? getRowCount(sheet, storeConfig) : countOverride
  };
  return state;
}
