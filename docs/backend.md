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

## How the app talks to the sheets

The app does **not** write to the spreadsheet directly. Every insert, edit, and deletion goes through a small
Apps Script web app bound to the spreadsheet itself, whose source lives in `server/` in this repository.

Two things follow from this that are visible in the sheet:

* a **stable id column** (column `L` of the Flight log), because the sheet is re-sorted on every change and row numbers
  therefore do not identify a flight for longer than a few seconds;
* the **pilot tokens** in the Metadata sheet, which is how the script knows who is calling.

The script mediates the **flight log only**. Bookings are unaffected: they stay on Google Calendar, written directly by
the app.

The request and response format is described in `server/openapi.yaml`, which is the reference for anything talking to
the deployment.

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
- [ ] Deploy the backend script into that spreadsheet and issue one token per pilot (see below)

## Google Sheet setup

You can start by copying the following template:

https://docs.google.com/spreadsheets/d/1ZpfdoaEA5rJmFmulG8tzBqBGPJdy5sk4j6B_8P776Qo/copy

The template includes all necessary sheets. The script that drives it is **not** part of the template any more: it
lives in `server/` in this repository and is deployed into the spreadsheet, as described in the next section.

### Sheet structure

| Sheet      | Columns                             | Notes                            |
|------------|-------------------------------------|----------------------------------|
| Flight log | `A:J` data, `K` flight time, `L` id | sorted by start and end hour     |
| Activities | (work in progress)                  | (work in progress)               |
| Metadata   | `A:B` key/value                     | versions, counters, pilot tokens |

The Flight log columns are fixed and positional: `A` creation timestamp, `B` date, `C` pilot name, `D` start hour,
`E` end hour, `F` origin, `G` destination, `H` fuel, `I` fuel price, `J` notes. The script writes the whole row on
every change and addresses the columns by position, so **do not reorder or insert columns**.

Column **K** is computed, not stored: the flight time comes from a formula in `K1` that spills down the column.
The script clears that cell on the rows it writes and never reads it back.

Column **L** holds a stable id, assigned by the script and never reused. Do not remove it, do not reorder it, and do
not fill it by hand: it is what identifies a flight for the app. The ids are ten lowercase characters starting with a
letter, e.g. `ab12cd34ef` — the leading letter is what stops the spreadsheet from reading an id back as a number,
which would make the row unfindable.

The Metadata sheet holds these keys:

| Key                                    | Meaning                                                |
|----------------------------------------|--------------------------------------------------------|
| `flight_log.hash`, `activities.hash`   | version number, changes at every modification          |
| `flight_log.count`, `activities.count` | number of rows                                         |
| `token.<pilot name>`                   | that pilot's token, stored as the app sends it         |
| `role.<pilot name>`                    | `pilot`, or `admin` to also edit other pilots' entries |

Of these the script writes only `flight_log.hash`, which it bumps after every change it makes; it assigns flight ids
itself, so there is no `next_id` counter to keep any more. The `count` keys are `COUNTA` formulas that the spreadsheet
keeps up to date on its own.

## Backend script setup

The script is bound to the spreadsheet and can only reach that one document: its manifest requests
`spreadsheets.currentonly`, so even though it runs with your account's identity it cannot touch any other
spreadsheet you own. Every aircraft therefore has its own copy and its own deployment URL.

1. Open the spreadsheet → Extensions → Apps Script. Note the script id from Project Settings.
2. Push the sources from this repository:

   ```shell
   cd server
   # put the script id in .clasp.json
   npx clasp login
   npx clasp push
   ```

   From then on use `./deploy.sh`, which pushes and redeploys in one step: see `server/README.md`.

3. In Project Settings → Script Properties, add:

   | Property                | Required | Value                                      |
   |-------------------------|----------|--------------------------------------------|
   | `METADATA_SHEET_NAME`   | yes      | `Metadata`                                 |
   | `FLIGHT_LOG_SHEET_NAME` | yes      | `Flight log` (or `Registro voli`)          |
   | `NO_PILOT_NAME`         | no       | the maintenance pilot name, if you use one |

4. There is no trigger to add. This script has no `onChange` function: every sort and every version bump happens
   inside the write it belongs to, so a change typed directly into the spreadsheet triggers neither — the next change
   made through the app puts both right.
5. Deploy → New deployment → Web app. Access and identity are already set in the manifest
   (execute as the owner, reachable by anyone with the URL). Keep the deployment id: redeploying **the same one** is
   what keeps the URL stable for apps already installed.
6. Check it answers, without any token:

   ```shell
   curl -L "https://script.google.com/macros/s/<deployment id>/exec"
   ```

   A JSON response means the deployment is reachable; it reports the build the deployment was made from and the
   protocol versions it speaks. An HTML page means the access setting is wrong and callers are being sent to a login
   page.

### Pilot tokens

Each pilot gets their own token, which goes in their copy of the aircraft archive as `script_token`. The script
compares what the app sends against the Metadata sheet exactly as stored, so the two have to be the same string:

* generate a long random value per pilot — 64 hexadecimal characters is a good shape, and it must be unguessable;
* add a `token.<pilot name>` row in the Metadata sheet with that value;
* add the matching `role.<pilot name>` row, without which the token is refused;
* put the same value in that pilot's archive.

The value in the sheet **is** the credential, not a verifier for it: whoever can read the Metadata sheet can act as
any pilot. Give read access to the spreadsheet only to people you would hand every pilot's token to.

To revoke a pilot, delete their row: it takes effect on their next request.

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
    // URL of the backend script deployment (ends with /exec).
    // Required for the flight log and the journal.
    "script_url": "https://script.google.com/macros/s/.../exec",
    // Token of the pilot this archive is for. Each pilot gets their own archive.
    "script_token": "...",
    // JSON-escaped string of the service account JSON file.
    // Only used for bookings now: remove it if not using the app for booking flights.
    "google_api_service_account": "{...}",
    // API key for accessing Google services.
    "google_api_key": "...",
    // ID of the Google Calendar used for booking flights.
    // Remove the line if not using the app for booking flights.
    "google_calendar_id": "...@group.calendar.google.com",
    // Enables the flight log. The sheet itself is resolved by the backend script.
    // Remove the line if not using the flight log.
    "flightlog_enabled": true,
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

> Since `script_token` identifies the pilot, you need **one archive per pilot**, each with that pilot's token.
> Everything else in the archive is identical.

You can then serve the zip file from anywhere you like, as long as it has a publicly accessible HTTPS URL, either
without authentication or with HTTP Basic authentication (the app supports no other authentication method).

> When using HTTP Basic authentication, you will need to type "username:password" in the password field during aircraft
> configuration in the app.
