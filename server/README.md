# Airborne backend (Google Apps Script)

Web App that mediates every write to the Google Sheets stores, so that
check-and-write happens inside a single mutually exclusive execution instead of
being split across two round trips from the app.

It is not a custom backend: it runs inside Google, next to the spreadsheets it
serves, and it holds no state of its own.

## Setup

Full end-to-end instructions, including the spreadsheet template, are in
`docs/backend.md`. In short:

1. Open the aircraft spreadsheet → Extensions → Apps Script, and put the script
   id of that bound project in `.clasp.json`.
2. Set the script properties (Project Settings → Script Properties):

   | Property                | Required       | Meaning                                      |
   |-------------------------|----------------|----------------------------------------------|
   | `METADATA_SHEET_NAME`   | yes            | name of the key-value sheet, e.g. `Metadata` |
   | `FLIGHT_LOG_SHEET_NAME` | for flight_log | e.g. `Flight log` or `Registro voli`         |
   | `NO_PILOT_NAME`         | no             | maintenance pilot, writable by any token     |

3. Add one `token.<pilot_name>` row per pilot to the metadata sheet, with the user's token.
   Optionally add `role.<pilot_name>` = `admin`.
4. Deploy as a Web App. The manifest already pins `executeAs: USER_DEPLOYING`
   and `access: ANYONE_ANONYMOUS`, so the settings are versioned here rather
   than clicked in a panel.
6. Verify with a `GET` on the `/exec` URL: it answers with the build id and the
   supported protocol range, without a token.

## Deploying

```shell
AIRBORNE_DEPLOYMENT_ID=<id> ./deploy.sh "description"
```

Redeploying the same deployment id is what keeps the `/exec` URL stable — plain
`clasp deploy` creates a new URL that no installed app knows about. Rollback is
the same command pointing at an earlier version.

With more than one aircraft, each spreadsheet has its own script id and
deployment id: run the script once per aircraft, switching `scriptId` in
`.clasp.json`.

## Tests

```shell
node --test 'test/*.test.js'
```

No dependencies: the pure modules are evaluated in a `vm` sandbox with stubs for
the handful of Apps Script services they touch. Anything that reaches
`SpreadsheetApp` is deliberately out of scope here and is exercised against a
real spreadsheet.

## Protocol

TODO OpenAPI file
