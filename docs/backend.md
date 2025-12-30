---
title: Airborne backend setup
layout: default
---

Backend setup
=============

All backend data is stored on the Google cloud.

# Data overview

## Bookings

Flight bookings are stored in a **Google Calendar**, having the pilot name as event title and the notes as event description.  
Events are created by the app with UTC time zone: the app will use the aircraft time zone to correct them.

## Log book

The log book uses a **Google Sheet** to store flights. The structure is very simple, see the Google Sheets template
linked below.

The log book is automatically sorted by start hour and end hour. There also some basic checks implemented using
conditional formatting.

# Setup a new aircraft

Here is what you need to do to setup a new aircraft.

# Google Cloud setup checklist

- [ ] Create a Google account for management or use the account of one of the pilots to setup all of the following
- [ ] Sign up to Google Cloud Platform (free tier)
- [ ] Enable APIs: Google Calendar, Google Sheets
- [ ] GCP: create API key with no application restriction and assign it APIs: Google Calendar, Google Sheets
- [ ] GCP: create service account and create (and download) a JSON key
- [ ] Create a new Google Calendar and assign write permissions to the service account and to all the pilots
- [ ] Create a new Google Sheet (see below) and assign write permissions to the service account and to all the pilots

## Google Sheet setup

You can start by copying the following template:

https://docs.google.com/spreadsheets/d/1ZpfdoaEA5rJmFmulG8tzBqBGPJdy5sk4j6B_8P776Qo/copy

The template includes all necessary sheets and scripts. However, the script needs a trigger to activate:

* open Apps Script from inside the Google Sheets document
* go to Triggers > Add Trigger
* select "onChange" as the function to run
* select "On change" as the event type
* save and authorize the trigger via your Google Account

### Custom sheet code

> The actual script is already included in the template, there is no need to copy it.
> It was copied here as reference only.

This code, when installed on the "On Change" event for the sheet, will:

* automatically sort the flight log rows by start and end hour
* automatically sort the activities log rows by priority and date
* update the hash of the sheets (more of a version number, actually)

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
  else if (sheetName.startsWith('Activities') || sheetName.startsWith('Attività')) {
    var range = sheet.getRange("A:I");
    range.sort([{ column : 3, ascending: false }, { column : 2, ascending: false }]);    

    // calculate checksum of data
    var metadataSheet = SpreadsheetApp.getActive().getSheetByName("Metadata");
    var finder = metadataSheet.createTextFinder("activities.hash").matchEntireCell(true);
    /** @type {SpreadsheetApp.Range} */
    var hashKeyCell = finder.findNext();
    if (hashKeyCell) {
      var hashValueCell = metadataSheet.getRange(hashKeyCell.getRow(), hashKeyCell.getColumn()+1);
       const currentVersion = hashValueCell.getValue() || 0;
       hashValueCell.setValue(currentVersion + 1);
    }
  }
}
```

## Aircraft definition file

The definition file contains all information about your aircraft, as well as the credentials to access the calendar and
the spreadsheet.

> Comments are only for documentation purposes and are not supported by the app! Please **remove them** before creating
> the zip file!

```json5
{
  // Gives administrative access to the user. Administrators can edit everything, even entries created by other people.
  "admin": false,
  // Internal ID of the aircraft. It's recommended to use the call sign in lowercase, without the hyphen.
  "aircraft_id": "a1234",
  // Aircraft call sign.
  "callsign": "A-1234",
  // Google Docs information.
  "backend_info": {
    // JSON-escaped string of the service account JSON file.
    "google_api_service_account": "{...}",
    // API key for accessing Google services.
    "google_api_key": "...",
    // ID of the Google Calendar used for booking flights.
    // Remove the line if not using the app for booking flights.
    "google_calendar_id": "...@group.calendar.google.com",
    // Spreadsheet ID of the Google Sheets document for the flight log.
    // Remove the line if not using the flight log.
    "flightlog_spreadsheet_id": "...",
    // Actual sheet name - within the spreadsheet - for the flight log
    // Remove the line if not using the flight log.
    "flightlog_sheet_name": "Flight log",
    // Spreadsheet ID of the Google Sheets document for the journal.
    // Remove the line if not using the journal.
    "activities_spreadsheet_id": "...",
    // Actual sheet name - within the spreadsheet - for the journal.
    // Remove the line if not using the journal.
    "activities_sheet_name": "Activities",
    // Spreadsheet ID of the Google Sheets document for the metadata table.
    "metadata_spreadsheet_id": "...",
    // Actual sheet name - within the spreadsheet - for the metadata table.
    "metadata_sheet_name": "Metadata"
  },
  // Name of the (fake) pilot when registering a maintenance flight or engine start.
  "no_pilot_name": "(maintenance)",
  // Name of the pilots.
  "pilot_names": [
    "Mike",
    "John",
    "Claudia",
    "Anna",
    "Simon"
  ],
  // URL to the documents archive of the aircraft.
  "documents_archive": "https://...",
  // Hangar location information.
  "location": {
    "name": "Fly Berlin",
    "latitude": 52.8844253,
    "longitude": 12.7143166,
    // This timezone will be used when booking flights in the calendar.
    "timezone": "Europe/Berlin",
    // Live weather information. Remove the line if none available.
    "weather_live": "https://www.earthtv.com/en/webcam/berlin-brandenburger-tor",
    // Weather forecast information. Remove the line if none available.
    "weather_forecast": "https://www.bbc.com/weather/2950159"
  }
}
```

## Aircraft data file

There is a [nice web tool to build an aircraft data file](https://daniele-athome.github.io/airborne/aircraft-tool/) (BETA);
if the tool doesn't work you can proceed with the manual process.

Create a zip file with the following:

* `aircraft.json`
* `avatar-<name>.jpg` files with picture of all pilots (names must match the ones in aircraft definition file, **but all lowercase**)
* `aircraft.jpg` with a picture of your aircraft

You can then serve the zip file from anywhere you like, as long as it has a publicly accessible HTTPS URL, either
without authentication or with HTTP Basic authentication (no other authentication method is supported by the app).

> When using HTTP Basic authentication, you will need to type "username:password" in the password field during aircraft
> configuration in the app.
