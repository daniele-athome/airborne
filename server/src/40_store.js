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
