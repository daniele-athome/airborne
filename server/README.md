# Airborne backend (Google Apps Script)

Web App that mediates every write to the Google Sheets stores, so that
check-and-write happens inside a single mutually exclusive execution instead of
being split across two round trips from the app.

It is not a custom backend: it runs inside Google, next to the spreadsheets it
serves, and it holds no state of its own.

## Why it exists

The app used to read a version hash, compare it, then write — two separate
calls. Two clients could both pass the check and both write, and the first write
was lost with no error. Everything here follows from closing that window:

- **Atomicity** — read, verify and write happen inside `LockService`.
- **No polling** — the new version travels back in the write response, so the
  app no longer waits for an external script to recompute a hash.
- **No credentials in the app** — the script runs as its owner; the app only
  carries a token.
- **Server-derived identity** — the pilot name comes from the token, not from
  the request body.
- **Stable ids** — the sheet is re-sorted on every change, so row numbers are
  not identities.

## Container-bound, by design

This script is **bound to the spreadsheet it serves**, and its manifest asks
only for `spreadsheets.currentonly`. There is no `openById` anywhere: every
sheet is reached through `SpreadsheetApp.getActive()`.

That matters because the web app runs as its owner. Without the narrow scope, a
deployment would hold write access to every spreadsheet in that account's Drive;
with it, a bug or a leaked URL cannot reach past this one document. It is the
same confinement the template's original trigger already declared with
`@OnlyCurrentDoc`.

The consequence is one deployment per aircraft, since each aircraft is a copy of
the template with its own bound script. That also means the script lock is
per-aircraft, which is the right granularity: two aircraft never serialize
against each other.

Booking stays on Google Calendar, handled directly by the app: there is no
`calendar.currentonly` equivalent, so pulling it in here would have widened the
scope back to the whole account.

## Layout

| File | Contents |
|---|---|
| `src/00_config.js` | protocol versions, store schemas, script properties |
| `src/10_protocol.js` | envelope validation, responses, error codes, cursors |
| `src/20_auth.js` | token hashing and lookup |
| `src/30_canonical.js` | row canonicalization and fingerprints (pure, tested) |
| `src/40_store.js` | sheet and metadata access |
| `src/50_lock.js` | script lock and idempotency |
| `src/60_actions.js` | bootstrap, list, insert, update, delete |
| `src/70_trigger.js` | `onChange`: sorting and version bump, under the same lock |
| `src/90_main.js` | `doGet` / `doPost` |

Apps Script has a flat global namespace and no module system: the numeric
prefixes are the load order, declared in `.clasp.json` under `filePushOrder`.

## Setup

Full end-to-end instructions, including the spreadsheet template, are in
`docs/backend.md`. In short:

1. Open the aircraft spreadsheet → Extensions → Apps Script, and put the script
   id of that bound project in `.clasp.json`.
2. Set the script properties (Project Settings → Script Properties):

   | Property | Required | Meaning |
   |---|---|---|
   | `TOKEN_SALT` | yes | salt for token hashes — never commit it, one per aircraft |
   | `METADATA_SHEET_NAME` | yes | name of the key-value sheet, e.g. `Metadata` |
   | `FLIGHT_LOG_SHEET_NAME` | for flight_log | e.g. `Flight log` or `Registro voli` |
   | `ACTIVITIES_SHEET_NAME` | for activities | e.g. `Activities` or `Attività` |
   | `NO_PILOT_NAME` | no | maintenance pilot, writable by any token |

   Sheet names are matched as a prefix by the trigger, mirroring what the
   template's original script did with its localized names.

3. Add one `token.<pilot_name>` row per pilot to the metadata sheet, with the
   **hash** of the token as its value (`SHA-256` of `TOKEN_SALT + token`, lower
   case hex). Optionally add `role.<pilot_name>` = `admin`.
4. Deploy as a Web App. The manifest already pins `executeAs: USER_DEPLOYING`
   and `access: ANYONE_ANONYMOUS`, so the settings are versioned here rather
   than clicked in a panel.
5. Install the `onChange` trigger: Triggers → Add Trigger → function `onChange`,
   event source "From spreadsheet", event type "On change". It has to be an
   installable trigger, because it writes.
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

`POST` with a JSON body; everything travels in the body so the token never
appears in a URL. Apps Script answers `200` for anything it manages to run, so
failures are reported in `error.code`.

```json
{ "v": 1, "token": "...", "action": "update", "store": "flight_log",
  "requestId": "uuid", "expect": { "fingerprint": "a3f19c" },
  "payload": { "id": "312", "startHour": 1247.3 } }
```

```json
{ "ok": true, "v": 1, "vMin": 1, "vMax": 1,
  "data": { "id": "312", "fingerprint": "b81e04", "...": "..." },
  "state": { "flight_log": { "hash": "4417", "count": 312 } } }
```

**`v`** is the contract version, not the app version, and moves only on breaking
changes. Clients must ignore unknown response fields and must have a fallback
for unknown error codes; with those two rules, adding a field, an action or an
error code needs no bump. `PROTOCOL_TOO_OLD` and `PROTOCOL_TOO_NEW` are both
real: the first when an app was not updated, the second after a rollback.

**`expect`** carries the fingerprint the client received with the item. It is
computed server-side over the whole row — including columns the app does not
map — so an edit typed directly into the spreadsheet is caught just like a
concurrent edit from another client. A conflict response carries the current row
under `error.details.current`, so the app can show what is there now.

**`requestId`** must be generated when the user confirms the action and kept
across retries; a new one per attempt defeats the purpose. Only successful
responses are memoized: `BUSY` and `CONFLICT` are meant to be retried with the
same id.

### Actions

| Action | Store | `expect` | `requestId` | Notes |
|---|---|---|---|---|
| `bootstrap` | — | — | — | validates the token, reports every store |
| `list` | yes | — | — | `payload: { cursor, pageSize }`, newest block first |
| `insert` | yes | — | yes | append cannot conflict with append |
| `update` | yes | yes | yes | preserves columns not in the payload |
| `delete` | yes | yes | yes | |

## Identity of a row

Ids are read from column **K**, assigned on insert from a `<store>.next_id`
counter in the metadata sheet, and never reused.

Row numbers cannot serve as ids here, and not merely because deleting a row
shifts the ones below it: the `onChange` trigger **re-sorts the whole sheet on
every change** — the flight log by hourmeter, the activities by priority and
date. A single backdated entry moves everything under it, so a positional id
would point at a different flight seconds after it was handed out.

One consequence deserves attention when touching the sort. `Range.sort()`
rearranges the values inside its range and leaves everything outside in place,
so an id column excluded from the sorted range would stay behind while its data
moved — silently attaching every id to the wrong row. `sortStore` therefore
derives the range from `headerRows` and `columnCount` instead of naming it, and
the same property is what rules out row-attached `DeveloperMetadata` as an
alternative: it is bound to the row dimension, which a value sort does not move.

## Operational notes

- The lock only covers executions of this script. Direct Sheets API writes and
  edits typed into the browser bypass it, which is why the app has to stop
  writing directly for the guarantee to hold.
- The `onChange` trigger lives in this project precisely so that it shares the
  lock: it skips its work when a write already holds it, since that write sorts
  and bumps the version on its way out.
- `count` is derived from the sheet, not trusted from the metadata counter: a
  row added by hand never touches the counter. The counter is still written for
  the app's current `reset()`.
- Both stores serialize against each other within one aircraft, since Apps
  Script offers no named locks. At this write volume that is irrelevant.
- `L1` set to `LOCKED` suspends sorting, the template's original escape hatch.
  It is what makes the id backfill safe to run — see the migration section of
  `docs/backend.md`.
