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

The app does **not** write to the spreadsheet directly. Every insert, edit and deletion goes through a small
Apps Script web app bound to the spreadsheet itself, whose source lives in `server/` in this repository.

The reason is atomicity. Reading the current state and then writing it back are two separate requests, and between
them another pilot can write: both clients see the same state, both write, and the first change is lost without any
error. Inside the script the check and the write happen in one execution guarded by a lock, so that cannot happen.

Two things follow from this that are visible in the sheet:

* a **stable id column** (column K), because the sheet is re-sorted on every change and row numbers therefore do not
  identify a flight for longer than a few seconds;
* the **pilot tokens** in the Metadata sheet, which is how the script knows who is calling.

Bookings are unaffected: they stay on Google Calendar, written directly by the app.

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

| Sheet | Columns | Notes |
|---|---|---|
| Flight log | `A:J` data, `K` id | sorted by start and end hour |
| Activities | `A:I` data, `K` id | sorted by priority and date |
| Metadata | `A:B` key/value | versions, counters, pilot tokens |

Column **K** holds a stable id, assigned by the script and never reused. Do not remove it, do not reorder it, and do
not fill it by hand: it is what identifies a flight for the app. `L1` is a manual switch — setting it to `LOCKED`
suspends the automatic sorting, which is needed during migrations.

The Metadata sheet holds these keys:

| Key | Meaning |
|---|---|
| `flight_log.hash`, `activities.hash` | version number, changes at every modification |
| `flight_log.count`, `activities.count` | number of rows |
| `flight_log.next_id`, `activities.next_id` | next id to assign |
| `token.<pilot name>` | **hash** of that pilot's token, never the token itself |
| `role.<pilot name>` | `admin` to allow editing other pilots' entries (optional) |

## Backend script setup

The script is bound to the spreadsheet and can only reach that one document: its manifest requests
`spreadsheets.currentonly`, so even though it runs with your account's identity it cannot touch any other
spreadsheet you own. Every aircraft therefore has its own copy and its own deployment URL.

1. Open the spreadsheet → Extensions → Apps Script. Note the script id from Project Settings.
2. Push the sources from this repository:

   ```shell
   cd server
   # put the script id in .clasp.json
   clasp login
   clasp push
   ```

3. In Project Settings → Script Properties, add:

   | Property | Value |
   |---|---|
   | `TOKEN_SALT` | a long random string, **different for every aircraft** |
   | `METADATA_SHEET_NAME` | `Metadata` |
   | `FLIGHT_LOG_SHEET_NAME` | `Flight log` (or `Registro voli`) |
   | `ACTIVITIES_SHEET_NAME` | `Activities` (or `Attività`) |
   | `NO_PILOT_NAME` | the maintenance pilot name, if you use one |

4. Add the trigger: Triggers → Add Trigger → function `onChange`, source "From spreadsheet", type "On change",
   then authorize it with your Google account. It sorts the sheets and updates the version number for changes typed
   directly into the spreadsheet; changes coming from the app are already handled inside the write itself.
5. Deploy → New deployment → Web app. Access and identity are already set in the manifest
   (execute as the owner, reachable by anyone with the URL). Keep the deployment id: redeploying **the same one** is
   what keeps the URL stable for apps already installed.
6. Check it answers, without any token:

   ```shell
   curl -L "https://script.google.com/macros/s/<deployment id>/exec"
   ```

   A JSON response means the deployment is reachable. An HTML page means the access setting is wrong and callers are
   being sent to a login page.

### Pilot tokens

Each pilot gets their own token, which goes in their copy of the aircraft archive. The spreadsheet only ever stores
its hash, so reading the Metadata sheet does not let anyone impersonate a pilot:

* generate a long random token per pilot;
* compute `SHA-256` of `TOKEN_SALT` concatenated with the token, lowercase hex;
* add a `token.<pilot name>` row in the Metadata sheet with that hash as the value.

To revoke a pilot, delete their row: it takes effect on their next request. The aircraft data tool does all of this
for you.

## Migrating an existing aircraft

An aircraft set up before the backend script existed needs the id column filled in. The order matters, because the
automatic sorting would otherwise scramble ids while you are adding them.

1. Set `L1` to `LOCKED` on both the Flight log and Activities sheets, to suspend sorting.
2. Delete the old `onChange` trigger and its script from the spreadsheet.
3. Deploy the new script as described above.
4. Add a header in `K1` and number the existing rows in column K, from 1 downwards, in whatever order they are in.
5. In the Metadata sheet, set `flight_log.next_id` and `activities.next_id` to one more than the highest id you used.
6. Clear `L1` on both sheets.
7. Update the aircraft archives with the web app URL and the pilot tokens, and distribute them.

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
    // Enables the journal.
    // Remove the line if not using the journal.
    "activities_enabled": true
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
without authentication or with HTTP Basic authentication (no other authentication method is supported by the app).

> When using HTTP Basic authentication, you will need to type "username:password" in the password field during aircraft
> configuration in the app.
