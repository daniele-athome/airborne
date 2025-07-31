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

This is the function used to calculate the flight log checksum:

```javascript
// input must be a scalar value
function HASH (input) {
  let hash = 0;
  for (let i = 0; i < input.length; i++) {
    hash = (hash << 5) - hash + input.charCodeAt(i);
    hash |= 0;
  }
  return Math.abs(hash);
}
```
