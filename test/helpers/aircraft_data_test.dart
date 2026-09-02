import 'dart:convert';
import 'dart:io';

import 'package:airborne/helpers/aircraft_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../fixtures/aircraft.dart';
import '../fixtures/path_provider.dart';
import '../generate_mocks.mocks.dart';

void main() {
  // for reading assets (the JSON schema)
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Asserts that every file of a valid aircraft archive landed in [directory].
  void expectAircraftFiles(Directory directory) {
    expect(directory.existsSync(), true);
    expect(File(path.join(directory.path, 'aircraft.json')).existsSync(), true);
    expect(File(path.join(directory.path, 'aircraft.jpg')).existsSync(), true);
    for (final name in kSamplePilotNames) {
      expect(
        File(
          path.join(directory.path, 'avatar-${name.toLowerCase()}.jpg'),
        ).existsSync(),
        true,
        reason: 'missing avatar for $name',
      );
    }
  }

  group('Testing aircraft data file validation', () {
    useFakePathProvider();

    test('A corrupted zip file should not pass validation', () async {
      final tmpDir = await getTemporaryDirectory();
      tmpDir.createSync(recursive: true);
      final badZipFile = File(path.join(tmpDir.path, 'aircraft_test.zip'));
      // damaged zip
      badZipFile.writeAsStringSync("PK###BAD ZIP FILE");
      final reader = AircraftDataReader(dataFile: badZipFile, urlFile: null);
      expect(await reader.validate(), false);
    });

    test(
      'A zip file with an invalid aircraft JSON file should not pass validation',
      () async {
        final badZipFile = await createAircraftZipFile(
          jsonData: '{3723;.-\\||}',
        );
        final reader = AircraftDataReader(dataFile: badZipFile, urlFile: null);
        expect(await reader.validate(), false);
      },
    );

    test(
      'A zip file with an aircraft JSON file missing stuff should not pass validation',
      () async {
        final badZipFile = await createAircraftZipFile(
          jsonData: '{"aircraft_id":"a1234","callsign":"A-1234"}',
        );
        final reader = AircraftDataReader(dataFile: badZipFile, urlFile: null);
        expect(await reader.validate(), false);
      },
    );

    test(
      'A zip file with a valid aircraft JSON file but missing stuff should not pass validation',
      () async {
        final goodZipFile = await createAircraftZipFile(
          jsonData: json.encode(aircraftMetadata()),
        );
        final reader = AircraftDataReader(dataFile: goodZipFile, urlFile: null);
        expect(await reader.validate(), false);
      },
    );
  });

  group('Testing aircraft data file opening', () {
    useFakePathProvider();

    // TODO some tests for bad cases here would be nice

    test('Aircraft data should exist in temp directory after open', () async {
      final goodZipFile = await createValidAircraftZipFile();
      final reader = AircraftDataReader(dataFile: goodZipFile, urlFile: null);
      final baseDir = await getTemporaryDirectory();
      final directory = Directory(path.join(baseDir.path, 'current_aircraft'));
      final actual = await reader.open();
      expect(actual.path, directory.path);
      expectAircraftFiles(directory);
    });

    test('Aircraft data should be stored as new aircraft', () async {
      final goodZipFile = await createValidAircraftZipFile();
      final reader = AircraftDataReader(dataFile: goodZipFile, urlFile: null);
      await reader.open();
      final storedFile = await addAircraftDataFile(
        reader,
        'http://localhost/a1234.zip',
      );
      final actualPath = path.join(
        fakePathProvider.baseDir,
        'appdata',
        'aircrafts',
        'a1234.zip',
      );
      expect(storedFile.path, actualPath);
      expect(File(actualPath).existsSync(), true);
    });

    test(
      'Loading existing aircraft should extract data in temp directory',
      () async {
        final goodZipFile = await createValidAircraftZipFile();
        final reader = AircraftDataReader(dataFile: goodZipFile, urlFile: null);
        await reader.open();
        await addAircraftDataFile(reader, 'http://localhost/a1234.zip');

        final loadedReader = await loadAircraft('a1234');
        final baseDir = await getTemporaryDirectory();
        final directory = Directory(
          path.join(baseDir.path, 'current_aircraft'),
        );
        final actual = await loadedReader.open();
        expect(actual.path, directory.path);
        expectAircraftFiles(directory);
      },
    );
  });

  group('Testing aircraft data download utilities', () {
    useFakePathProvider();

    test('Aircraft data valid download', () async {
      final downloadProvider = MockDownloadProvider();
      const url = 'http://localhost/a1234.zip';
      final aircraftFile = await createValidAircraftZipFile();
      when(
        downloadProvider.downloadToFile(url, 'aircraft.zip', null, null, true),
      ).thenAnswer((_) => Future.value(aircraftFile));
      final aircraftData = await downloadAircraftData(
        url,
        null,
        downloadProvider,
      );

      final baseDir = await getTemporaryDirectory();
      final directory = Directory(path.join(baseDir.path, 'current_aircraft'));
      expect(aircraftData.dataPath!.path, directory.path);
      expectAircraftFiles(directory);
    });

    test(
      'Aircraft data invalid (JSON schema not validated) download',
      () async {
        final downloadProvider = MockDownloadProvider();
        const url = 'http://localhost/a1234.zip';
        // trailing comma: not even valid JSON
        final aircraftFile = await createAircraftZipFile(
          jsonData: '''
{
  "backend_info": {
    "google_api_service_account": "BLABLABLA",
    "google_api_key": "API_KEY_NONE",
    "google_calendar_id": "NO_CALENDAR_MAN"
  },
}''',
          aircraftPicData: samplePictureData(),
          pilotAvatarsPicData: {
            for (final name in kSamplePilotNames)
              name.toLowerCase(): samplePictureData(),
          },
        );
        when(
          downloadProvider.downloadToFile(
            url,
            'aircraft.zip',
            null,
            null,
            true,
          ),
        ).thenAnswer((_) => Future.value(aircraftFile));
        expect(
          downloadAircraftData(url, null, downloadProvider),
          throwsA(predicate((e) => e is AircraftValidationException)),
        );
      },
    );

    test('Aircraft data invalid (missing files) download', () async {
      final downloadProvider = MockDownloadProvider();
      const url = 'http://localhost/a1234.zip';
      final aircraftFile = await createAircraftZipFile(
        jsonData: json.encode(aircraftMetadata()),
      );
      when(
        downloadProvider.downloadToFile(url, 'aircraft.zip', null, null, true),
      ).thenAnswer((_) => Future.value(aircraftFile));
      expect(
        downloadAircraftData(url, null, downloadProvider),
        throwsA(predicate((e) => e is AircraftValidationException)),
      );
    });

    test('Aircraft data download error', () async {
      final downloadProvider = MockDownloadProvider();
      const url = 'http://localhost/a1234.zip';
      when(
        downloadProvider.downloadToFile(url, 'aircraft.zip', null, null, true),
      ).thenAnswer(
        (_) => Future.error(
          const SocketException('Error connecting', osError: OSError()),
        ),
      );
      expect(
        downloadAircraftData(url, null, downloadProvider),
        throwsA(predicate((e) => e is SocketException)),
      );
    });
  });
}
