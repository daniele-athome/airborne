# Airborne

[![android](https://github.com/daniele-athome/airborne/actions/workflows/android.yml/badge.svg)](https://github.com/daniele-athome/airborne/actions/workflows/android.yml)
[![ios](https://github.com/daniele-athome/airborne/actions/workflows/ios.yml/badge.svg)](https://github.com/daniele-athome/airborne/actions/workflows/ios.yml)
[![linux](https://github.com/daniele-athome/airborne/actions/workflows/linux.yml/badge.svg)](https://github.com/daniele-athome/airborne/actions/workflows/linux.yml)
[![windows](https://github.com/daniele-athome/airborne/actions/workflows/windows.yml/badge.svg)](https://github.com/daniele-athome/airborne/actions/workflows/windows.yml)

Minimal aircraft management app for small groups.

<!-- TODO remove padding on google play badge -->

<a href='https://play.google.com/store/apps/details?id=it.casaricci.airborne'><img alt='Get it on Google Play' src='https://github.com/daniele-athome/airborne/raw/master/docs/google_play_badge.png' style='height: 60px'/></a>
<a href="https://apps.apple.com/us/app/airborne-aircraft-management/id1582860258" style="display: inline-block; overflow: hidden; border-radius: 13px; height: 60px;"><img src="https://github.com/daniele-athome/airborne/raw/master/docs/app_store_badge.png" alt="Download on the App Store" style="border-radius: 13px; height: 60px"></a>

## Features

* Aircraft reservations (booking)
* Flight logbook

## Screenshots

### Android

<p>
<img src="/android/fastlane/metadata/android/en-US/images/phoneScreenshots/Nexus%205X-Portrait-01-bookflight-agenda.png" alt="Bookings - Agenda" width="15%">
<img src="/android/fastlane/metadata/android/en-US/images/phoneScreenshots/Nexus%205X-Portrait-02-bookflight-month.png" alt="Bookings - Month" width="15%">
<img src="/android/fastlane/metadata/android/en-US/images/phoneScreenshots/Nexus%205X-Portrait-03-bookflight-flighteditor.png" alt="Bookings - Edit" width="15%">
<img src="/android/fastlane/metadata/android/en-US/images/phoneScreenshots/Nexus%205X-Portrait-04-logbook-list.png" alt="Logbook - List" width="15%">
<img src="/android/fastlane/metadata/android/en-US/images/phoneScreenshots/Nexus%205X-Portrait-05-logbook-flighteditor.png" alt="Logbook - Edit" width="15%">
<img src="/android/fastlane/metadata/android/en-US/images/phoneScreenshots/Nexus%205X-Portrait-50-onboarding-pilotselect.png" alt="Onboarding - Pilot" width="15%">
</p>

### iOS

<p>
<img src="/ios/fastlane/screenshots/en-US/iPhone%208%20Plus-Portrait-01-bookflight-agenda.png" alt="Bookings - Agenda" width="15%">
<img src="/ios/fastlane/screenshots/en-US/iPhone%208%20Plus-Portrait-02-bookflight-month.png" alt="Bookings - Month" width="15%">
<img src="/ios/fastlane/screenshots/en-US/iPhone%208%20Plus-Portrait-03-bookflight-flighteditor.png" alt="Bookings - Edit" width="15%">
<img src="/ios/fastlane/screenshots/en-US/iPhone%208%20Plus-Portrait-04-logbook-list.png" alt="[Logbook - List" width="15%">
<img src="/ios/fastlane/screenshots/en-US/iPhone%208%20Plus-Portrait-05-logbook-flighteditor.png" alt="[Logbook - Edit" width="15%">
<img src="/ios/fastlane/screenshots/en-US/iPhone%208%20Plus-Portrait-06-onboarding-pilotselect.png" alt="Onboarding - Pilot" width="15%">
</p>

## Build

You can refer to [Flutter documentation](https://docs.flutter.dev/) for build instructions. Currently supported
platforms are:

* Android
* iOS
* Linux
* Windows

## Backend

Everything is stored in the Google cloud and data is accessed through Google API directly:

* A Google Calendar for booking flights
* A Google Sheets for logging flights

The app needs a specially crafted zip file containing, among other information, credentials for accessing to Google
services. Documentation about that can be found in our [backend guide](docs/backend.md).

## Privacy

Airborne only uses Google services to store data on behalf of a service account you need to create in order to use the
app. You can learn more at our very small [privacy policy](docs/privacy.md).
