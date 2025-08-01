Backend setup
=============

All backend data is stored on the Google cloud.

# Data overview

## Bookings

Flight bookings are stored in a **Google Calendar**, having the pilot name as event title and the notes as event description.  
Events are created by the app with UTC time zone: the app will use the aircraft time zone to correct them.

## Log book

> TODO describe sheet usage

# Setup checklist

- [ ] Create a Google account for management or use the account of one of the pilots to setup all of the following
- [ ] Sign up to Google Cloud Platform (free tier)
- [ ] Enable APIs: Google Calendar, Google Sheets
- [ ] GCP: create API key with no application restriction and assign it APIs: Google Calendar, Google Sheets
- [ ] GCP: create service account and create (and download) a JSON key
- [ ] Create a new Google Calendar and assign write permissions to the service account and to all the pilots
- [ ] Create a new Google Sheet (see below) and assign write permissions to the service account and to all the pilots

## Google Sheet setup

> TODO log book sheet creation and formulas

### Custom sheet code

This code, if installed on the "On Change" event for the sheet, will:

* automatically sort the flight log rows by start and end hour
* update the flight log hash (actually uses the current time)
* automatically sort the activities log rows by priority and date

```javascript
/** @OnlyCurrentDoc */

// attached to installed trigger for onChange event
function onChange(event){
  var sheet = event.source.getActiveSheet();
  console.log("activeSheet=" + sheet.getName());
  var sheetName = sheet.getName();
  if (sheetName.startsWith('Flight log') || sheetName.startsWith('Registro voli')) {
    if (sheet.getRange('L1').getValue() != 'LOCKED') {
      var range = sheet.getRange("A:J");
      range.sort([{ column : 4 }, { column : 5 }]);
    }

    // calculate checksum of data
    var metadataSheet = SpreadsheetApp.getActive().getSheetByName("Metadata");
    var finder = metadataSheet.createTextFinder("flight_log.hash").matchEntireCell(true);
    /** @type {SpreadsheetApp.Range} */
    var hashKeyCell = finder.findNext();
    if (hashKeyCell) {
      var hashValueCell = metadataSheet.getRange(hashKeyCell.getRow(), hashKeyCell.getColumn()+1);
       const currentVersion = hashValueCell.getValue() || 0;
       hashValueCell.setValue(currentVersion + 1);
    }

  }
  else if (sheetName.startsWith('Activites') || sheetName.startsWith('Attività')) {
    var range = sheet.getRange("A:I");
    range.sort([{ column : 3, ascending: false }, { column : 2 }]);    
  }
}
```
