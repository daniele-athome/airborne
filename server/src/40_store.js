/** Data range of the metadata key-value store. */
const METADATA_FIRST_ROW = 2;

/**
 * Returns a sheet of the container spreadsheet, or throws if it is missing.
 * @returns {GoogleAppsScript.Spreadsheet.Sheet}
 */
function openSheetByName(sheetName) {
    const sheet = SpreadsheetApp.getActive().getSheetByName(sheetName);
    if (!sheet) {
        throw new Error('Sheet not found in this spreadsheet: ' + sheetName);
    }
    return sheet;
}

function openMetadataSheet() {
    return openSheetByName(getProperty('METADATA_SHEET_NAME', true));
}

function openFlightLogSheet() {
    return openSheetByName(getProperty('FLIGHT_LOG_SHEET_NAME', true));
}

function findRow(sheetConfig, sheet, stableId) {
    const lastRow = sheet.getLastRow();
    // Also covers the empty sheet, where getLastRow() is 0
    if (lastRow <= sheetConfig.headerRows) {
        return -1;
    }

    const rows = lastRow - sheetConfig.headerRows;
    const range = sheet.getRange(sheetConfig.headerRows + 1, sheetConfig.stableIdColumn, rows, 1)
        .createTextFinder(stableId)
        .matchEntireCell(true)
        .matchCase(true)
        .findNext();

    return range ? range.getRow() : -1;
}

function readRow(sheetConfig, sheet, rowIndex) {
    const rows = sheet.getRange(rowIndex, 1, 1, sheetConfig.schema.length)
        .getValues();
    return rows.length ? rows[0] : null;
}

function writeRow(sheetConfig, sheet, rowIndex, values) {
    sheet.getRange(rowIndex, 1, 1, sheetConfig.schema.length)
        .setValues([values])
}

function appendRow(sheet, values) {
  sheet.appendRow(values);
}

function deleteRow(sheet, rowIndex) {
    sheet.deleteRow(rowIndex);
}

/** Reads the whole metadata key-value store as a plain object. */
function readMetadata() {
    const sheet = openMetadataSheet();
    const lastRow = sheet.getLastRow();
    const store = {};
    if (lastRow < METADATA_FIRST_ROW) {
        return store;
    }
    const values = sheet.getRange(METADATA_FIRST_ROW, 1, lastRow - METADATA_FIRST_ROW + 1, 2).getValues();
    for (let i = 0; i < values.length; i++) {
        const key = values[i][0];
        if (key !== null && key !== undefined && key !== '') {
            store[String(key)] = values[i][1] === null || values[i][1] === undefined ? '' : String(values[i][1]);
        }
    }
    return store;
}


/** Maps the configured sort field names to 1-based column numbers. */
function sortSpecFor(sheetConfig) {
    const spec = [];
    for (let i = 0; i < sheetConfig.sort.length; i++) {
        const name = sheetConfig.sort[i];
        for (let f = 0; f < sheetConfig.schema.length; f++) {
            if (sheetConfig.schema[f].name === name) {
                spec.push({column: sheetConfig.schema[f].index + 1});
                break;
            }
        }
    }
    return spec;
}

function sortSheet(sheetConfig, sheet) {
    const firstRow = sheetConfig.headerRows + 1;
    const lastRow = sheet.getLastRow();
    if (lastRow < firstRow) {
        return;
    }

    // We'll sort only the data we manage
    sheet.getRange(firstRow, 1, lastRow - firstRow + 1, sheetConfig.schema.length)
        .sort(sortSpecFor(sheetConfig));
}

/** Bumps the version counter the app watches to know the data moved. */
function updateVersionMetadata(metadataKey) {
    const metadataSheet = openMetadataSheet();
    /** @type {GoogleAppsScript.Spreadsheet.Range} */
    const hashKeyCell = metadataSheet.getRange('A:A')
        .createTextFinder(metadataKey)
        .matchEntireCell(true)
        .findNext();

    if (!hashKeyCell) {
        appendRow(metadataSheet, [metadataKey, 1]);
        return;
    }

    const hashValueCell = metadataSheet.getRange(hashKeyCell.getRow(), hashKeyCell.getColumn() + 1);
    const current = Number(hashValueCell.getValue());
    hashValueCell.setValue(isNaN(current) ? 1 : current + 1);
}

/** Commits any pending writes. */
function commitChanges() {
    SpreadsheetApp.flush();
}

/* Test-only: see test/load.js. Apps Script has no `module`, so this never runs there. */
if (typeof module === 'object') {
    module.exports = {
        METADATA_FIRST_ROW,
        openSheetByName, openMetadataSheet, openFlightLogSheet,
        findRow, readRow, writeRow, appendRow, deleteRow, readMetadata,
        sortSpecFor, sortSheet, updateVersionMetadata, commitChanges
    };
}
