/** @OnlyCurrentDoc */

// attached to installed trigger for onChange event
// @deprecated
function onChange(event){
    const sheet = event.source.getActiveSheet();
    console.log("activeSheet=" + sheet.getName());
    const sheetName = sheet.getName();
    if (sheetName.startsWith('Flight log') || sheetName.startsWith('Registro voli')) {
        if (sheet.getRange('L1').getValue() != 'LOCKED') {
            const range = sheet.getRange("A:K");
            range.sort([{ column : 4 }, { column : 5 }]);
        }

        fillEmptyIds(sheet);

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

function fillEmptyIds(sh) {
    const chars = "0123456789abcdefghijklmnopqrstuvwxyz";
    const startRow = 2;  // first data row (skip header)
    const col = 11;      // column K

    const lastRow = sh.getLastRow();
    if (lastRow < startRow) return;

    const range = sh.getRange(startRow, col, lastRow - startRow + 1, 1);
    const values = range.getValues();

    // Keep track of existing ids to avoid collisions
    const seen = new Set(values.map(r => String(r[0]).trim()).filter(v => v !== ""));

    let filled = 0;
    for (let i = 0; i < values.length; i++) {
        if (String(values[i][0]).trim() !== "") continue;  // already filled, skip

        let id;
        do {
            id = "";
            for (let j = 0; j < 10; j++) {
                id += chars.charAt(Math.floor(Math.random() * chars.length));
            }
        } while (seen.has(id));

        seen.add(id);
        values[i][0] = id;
        filled++;
    }

    if (filled > 0) range.setValues(values);
}
