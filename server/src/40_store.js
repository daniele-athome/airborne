
/** Returns a sheet of the container spreadsheet, or throws if it is missing. */
function openSheetByName(sheetName, what) {
    const sheet = SpreadsheetApp.getActive().getSheetByName(sheetName);
    if (!sheet) {
        throw new Error(what + ' sheet not found in this spreadsheet: ' + sheetName);
    }
    return sheet;
}

function openMetadataSheet() {
    return openSheetByName(getProperty('METADATA_SHEET_NAME', true));
}
