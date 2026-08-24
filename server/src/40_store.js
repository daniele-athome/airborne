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

function findRow(sheetConfig, sheet, stableId) {
    const lastRow = sheet.getLastRow();
    // TODO verify this condition
    if (lastRow <= sheetConfig.headerRows) {
        return -1;
    }

    const range = sheet.getRange(sheetConfig.headerRows + 1, sheetConfig.stableIdColumn, lastRow, 1)
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
