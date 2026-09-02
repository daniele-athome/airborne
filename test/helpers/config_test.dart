import 'package:airborne/helpers/aircraft_data.dart';
import 'package:airborne/helpers/config.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../fixtures/aircraft.dart';
import '../fixtures/path_provider.dart';

/// Everything `backendInfo` must carry for the flight log to be available.
const kFlightLogBackendInfo = {
  'flightlog_spreadsheet_id': 'LOG_ID',
  'flightlog_sheet_name': 'Log',
  'script_url': 'https://script.example/exec',
  'script_token': 'TOKEN',
  'flightlog_enabled': true,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(tz_data.initializeTimeZones);

  group('AppConfig', () {
    useFakePathProvider();

    setUp(() => SharedPreferences.setMockInitialValues({}));

    /// An initialized config, optionally already holding an aircraft.
    Future<AppConfig> buildConfig({Map<String, dynamic>? metadata}) async {
      final config = AppConfig();
      addTearDown(config.dispose);
      await config.init();
      if (metadata != null) {
        await config.setCurrentAircraft(
          await createSampleAircraftData(metadata: metadata),
        );
      }
      return config;
    }

    group('hasFeature', () {
      test('says no to everything without an aircraft', () async {
        final config = await buildConfig();
        for (final feature in [
          'book_flight',
          'flight_log',
          'activities',
          'metadata',
          // not even an unknown feature throws while there is no aircraft
          'nonsense',
        ]) {
          expect(config.hasFeature(feature), false, reason: feature);
        }
      });

      test('book_flight needs a calendar', () async {
        final withCalendar = await buildConfig(
          metadata: aircraftMetadata(
            backendInfo: {'google_calendar_id': 'CAL_ID'},
          ),
        );
        expect(withCalendar.hasFeature('book_flight'), true);

        final without = await buildConfig(
          metadata: aircraftMetadata(backendInfo: const {}),
        );
        expect(without.hasFeature('book_flight'), false);
      });

      test('flight_log needs the whole backend configuration', () async {
        final enabled = await buildConfig(
          metadata: aircraftMetadata(
            backendInfo: kFlightLogBackendInfo,
            noPilotName: 'Nobody',
          ),
        );
        expect(enabled.hasFeature('flight_log'), true);

        // every single ingredient is required
        for (final missing in kFlightLogBackendInfo.keys) {
          final config = await buildConfig(
            metadata: aircraftMetadata(
              backendInfo: {...kFlightLogBackendInfo}..remove(missing),
              noPilotName: 'Nobody',
            ),
          );
          expect(config.hasFeature('flight_log'), false, reason: 'no $missing');
        }

        final withoutNoPilot = await buildConfig(
          metadata: aircraftMetadata(backendInfo: kFlightLogBackendInfo),
        );
        expect(withoutNoPilot.hasFeature('flight_log'), false);
      });

      test('flight_log needs the flag to be exactly true', () async {
        final config = await buildConfig(
          metadata: aircraftMetadata(
            backendInfo: {...kFlightLogBackendInfo, 'flightlog_enabled': 'yes'},
            noPilotName: 'Nobody',
          ),
        );
        expect(config.hasFeature('flight_log'), false);
      });

      test('never promises a flight log it cannot configure', () async {
        // main.dart builds FlightLogBookService out of flightlogBackendInfo as
        // soon as hasFeature says yes, and that map cannot hold nulls
        for (final missing in kFlightLogBackendInfo.keys) {
          final config = await buildConfig(
            metadata: aircraftMetadata(
              backendInfo: {...kFlightLogBackendInfo}..remove(missing),
              noPilotName: 'Nobody',
            ),
          );
          if (config.hasFeature('flight_log')) {
            expect(
              () => config.flightlogBackendInfo,
              returnsNormally,
              reason: 'no $missing',
            );
          }
        }
      });

      test('activities and metadata need both id and sheet name', () async {
        for (final feature in ['activities', 'metadata']) {
          final complete = await buildConfig(
            metadata: aircraftMetadata(
              backendInfo: {
                '${feature}_spreadsheet_id': 'SHEET_ID',
                '${feature}_sheet_name': 'Sheet1',
              },
            ),
          );
          expect(complete.hasFeature(feature), true, reason: feature);

          final noName = await buildConfig(
            metadata: aircraftMetadata(
              backendInfo: {'${feature}_spreadsheet_id': 'SHEET_ID'},
            ),
          );
          expect(
            noName.hasFeature(feature),
            false,
            reason: '$feature, no name',
          );

          final noId = await buildConfig(
            metadata: aircraftMetadata(
              backendInfo: {'${feature}_sheet_name': 'Sheet1'},
            ),
          );
          expect(noId.hasFeature(feature), false, reason: '$feature, no id');
        }
      });

      test('refuses a feature it does not know', () async {
        final config = await buildConfig(metadata: aircraftMetadata());
        expect(() => config.hasFeature('teleport'), throwsException);
      });
    });

    group('backend info', () {
      test('exposes the Google credentials', () async {
        final config = await buildConfig(
          metadata: aircraftMetadata(
            backendInfo: {
              'google_api_service_account': '{"type":"service_account"}',
              'google_api_key': 'API_KEY',
              'google_calendar_id': 'CAL_ID',
              'script_url': 'https://script.example/exec',
              'script_token': 'TOKEN',
            },
          ),
        );

        expect(config.googleServiceAccountJson, '{"type":"service_account"}');
        expect(config.googleApiKey, 'API_KEY');
        expect(config.googleCalendarId, 'CAL_ID');
        expect(config.scriptUrl, 'https://script.example/exec');
        expect(config.scriptToken, 'TOKEN');
      });

      test('bundles what each service needs', () async {
        final config = await buildConfig(
          metadata: aircraftMetadata(
            backendInfo: {
              'flightlog_spreadsheet_id': 'LOG_ID',
              'flightlog_sheet_name': 'Log',
              'script_url': 'https://script.example/exec',
              'script_token': 'TOKEN',
              'activities_spreadsheet_id': 'ACT_ID',
              'activities_sheet_name': 'Activities',
              'metadata_spreadsheet_id': 'META_ID',
              'metadata_sheet_name': 'Metadata',
            },
          ),
        );

        expect(config.flightlogBackendInfo, {
          'spreadsheet_id': 'LOG_ID',
          'sheet_name': 'Log',
          'script_url': 'https://script.example/exec',
          'script_token': 'TOKEN',
        });
        expect(config.activitiesBackendInfo, {
          'spreadsheet_id': 'ACT_ID',
          'sheet_name': 'Activities',
        });
        expect(config.metadataBackendInfo, {
          'spreadsheet_id': 'META_ID',
          'sheet_name': 'Metadata',
        });
      });

      test('reports whether this pilot is an administrator', () async {
        final admin = await buildConfig(metadata: aircraftMetadata());
        expect(admin.admin, true);

        final plain = await buildConfig(
          metadata: aircraftMetadata(admin: false),
        );
        expect(plain.admin, false);
      });
    });

    group('location', () {
      test('exposes where the aircraft is parked', () async {
        final config = await buildConfig(metadata: aircraftMetadata());

        expect(config.locationName, 'Fly Berlin');
        expect(config.locationLatitude, 52.8844253);
        expect(config.locationLongitude, 12.7143166);
        expect(config.locationTimeZone, tz.getLocation('Europe/Berlin'));
      });

      test('builds a maps url out of the coordinates', () async {
        final config = await buildConfig(metadata: aircraftMetadata());
        expect(
          config.locationMapsUrl,
          'https://www.google.com/maps/search/?api=1&query=52.8844253,12.7143166',
        );
      });
    });

    group('aircraft properties', () {
      test('defaults the hourmeter to hundredths of an hour', () async {
        final byDefault = await buildConfig(metadata: aircraftMetadata());
        expect(byDefault.hourmeterMultiplier, 60);

        final explicit = await buildConfig(
          metadata: aircraftMetadata(hourmeterMultiplier: 100),
        );
        expect(explicit.hourmeterMultiplier, 100);
      });

      test('has a hard-coded fuel currency', () async {
        final config = await buildConfig(metadata: aircraftMetadata());
        expect(config.fuelPriceCurrency, '€');
      });
    });

    group('pilots', () {
      test('lists the pilots as declared', () async {
        final config = await buildConfig(metadata: aircraftMetadata());
        expect(config.pilotNames, kSamplePilotNames);
        expect(config.noPilotName, isNull);
      });

      test('puts the no-pilot name first when there is one', () async {
        final config = await buildConfig(
          metadata: aircraftMetadata(noPilotName: 'Nobody'),
        );
        expect(config.noPilotName, 'Nobody');
        expect(config.pilotNamesWithNoPilot, ['Nobody', ...kSamplePilotNames]);
      });

      test('serves the bundled avatar for the no-pilot name', () async {
        final config = await buildConfig(
          metadata: aircraftMetadata(noPilotName: 'Nobody'),
        );

        expect(
          config.getPilotAvatar('Nobody'),
          const AssetImage('assets/images/nopilot_avatar.png'),
        );

        final anna = config.getPilotAvatar('Anna') as FileImage;
        expect(anna.file.path, endsWith('avatar-anna.jpg'));
        expect(anna.file.existsSync(), true);
      });

      test('serves the aircraft picture from the cache', () async {
        final config = await buildConfig(metadata: aircraftMetadata());
        final picture = config.aircraftPicture as FileImage;
        expect(picture.file.path, endsWith('aircraft.jpg'));
        expect(picture.file.existsSync(), true);
      });
    });

    group('persistence', () {
      test('remembers the current aircraft', () async {
        final config = await buildConfig();
        var notifications = 0;
        config.addListener(() => notifications++);

        final aircraft = await createSampleAircraftData();
        await config.setCurrentAircraft(aircraft);

        expect(config.currentAircraft, same(aircraft));
        expect(notifications, 1);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('currentAircraft'), kSampleAircraftId);
      });

      test('forgets the aircraft when told to', () async {
        final config = await buildConfig(metadata: aircraftMetadata());

        await config.setCurrentAircraft(null);

        expect(config.currentAircraft, isNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('currentAircraft'), isNull);
      });

      test('remembers the pilot', () async {
        final config = await buildConfig();
        var notifications = 0;
        config.addListener(() => notifications++);

        config.pilotName = 'Anna';
        expect(config.pilotName, 'Anna');
        expect(notifications, 1);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('pilotName'), 'Anna');

        config.pilotName = null;
        expect(config.pilotName, isNull);
        expect(notifications, 2);
        expect(prefs.getString('pilotName'), isNull);
      });

      test('logout drops both the aircraft and the pilot', () async {
        final config = await buildConfig(metadata: aircraftMetadata());
        config.pilotName = 'Anna';

        await config.logout();

        expect(config.currentAircraft, isNull);
        expect(config.pilotName, isNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('currentAircraft'), isNull);
        expect(prefs.getString('pilotName'), isNull);
      });
    });

    group('init', () {
      test('starts empty when nothing was stored', () async {
        final config = await buildConfig();
        expect(config.currentAircraft, isNull);
        expect(config.pilotName, isNull);
      });

      test('reloads the aircraft stored last time', () async {
        // what addAircraftDataFile leaves behind after an onboarding
        final zipFile = await createValidAircraftZipFile();
        final reader = AircraftDataReader(dataFile: zipFile, urlFile: null);
        await reader.open();
        await addAircraftDataFile(reader, 'https://example.com/a1234.zip');

        SharedPreferences.setMockInitialValues({
          'currentAircraft': kSampleAircraftId,
          'pilotName': 'Anna',
        });

        final config = AppConfig();
        addTearDown(config.dispose);
        await config.init();

        expect(config.currentAircraft?.id, kSampleAircraftId);
        expect(config.currentAircraft?.callSign, kSampleCallSign);
        expect(config.pilotName, 'Anna');
      });

      test('cleans up after an aircraft it can no longer read', () async {
        SharedPreferences.setMockInitialValues({
          'currentAircraft': 'ghost',
          'pilotName': 'Anna',
        });

        final config = AppConfig();
        addTearDown(config.dispose);
        await config.init();

        expect(config.currentAircraft, isNull);
        expect(config.pilotName, isNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('currentAircraft'), isNull);
        expect(prefs.getString('pilotName'), isNull);
      });
    });
  });
}
