/** @OnlyCurrentDoc */

// attached to installed trigger for onChange event
// @deprecated
function onChange(event){
    const sheet = event.source.getActiveSheet();
    console.log("activeSheet=" + sheet.getName());
    const sheetName = sheet.getName();
    if (sheetName.startsWith('Flight log') || sheetName.startsWith('Registro voli')) {
        if (sheet.getRange('L1').getValue() != 'LOCKED') {
            const range = sheet.getRange("A:J");
            range.sort([{ column : 4 }, { column : 5 }]);
        }

        // calculate checksum of data
        const metadataSheet = SpreadsheetApp.getActive().getSheetByName("Metadata");
        const finder = metadataSheet.createTextFinder("flight_log.hash").matchEntireCell(true);
        /** @type {SpreadsheetApp.Range} */
        const hashKeyCell = finder.findNext();
        if (hashKeyCell) {
            const hashValueCell = metadataSheet.getRange(hashKeyCell.getRow(), hashKeyCell.getColumn()+1);
            const currentVersion = hashValueCell.getValue() || 0;
            hashValueCell.setValue(currentVersion + 1);
        }

    }
    else if (sheetName.startsWith('Activities') || sheetName.startsWith('Attività')) {
        const range = sheet.getRange("A:I");
        range.sort([{ column : 3, ascending: false }, { column : 2, ascending: false }]);

        // calculate checksum of data
        const metadataSheet = SpreadsheetApp.getActive().getSheetByName("Metadata");
        const finder = metadataSheet.createTextFinder("activities.hash").matchEntireCell(true);
        /** @type {SpreadsheetApp.Range} */
        const hashKeyCell = finder.findNext();
        if (hashKeyCell) {
            const hashValueCell = metadataSheet.getRange(hashKeyCell.getRow(), hashKeyCell.getColumn()+1);
            const currentVersion = hashValueCell.getValue() || 0;
            hashValueCell.setValue(currentVersion + 1);
        }
    }
}
