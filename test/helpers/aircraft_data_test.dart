import 'dart:io';
import 'dart:math';

import 'package:airborne/helpers/aircraft_data.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../generate_mocks.mocks.dart';

void main() {
  // for reading assets (the JSON schema)
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Testing aircraft data file validation', () {
    setUp(() {
      PathProviderPlatform.instance = MockPathProviderPlatform();
    });
    tearDown(() {
      Directory(
        (PathProviderPlatform.instance as MockPathProviderPlatform).baseDir,
      ).deleteSync(recursive: true);
    });

    test('A corrupted zip file should not pass validation', () async {
      final tmpDir = await getTemporaryDirectory();
      tmpDir.createSync(recursive: true);
      final badZipFile = File(
        path.join(tmpDir.path, 'aircraft_test_${Random().nextInt(1000)}.zip'),
      );
      // damaged zip
      badZipFile.writeAsStringSync("PK###BAD ZIP FILE");
      final reader = AircraftDataReader(dataFile: badZipFile, urlFile: null);
      expect(await reader.validate(), false);
    });

    test(
      'A zip file with an invalid aircraft JSON file should not pass validation',
      () async {
        final badZipFile = await _createAircraftFileWithData(
          filenameWithoutExtension: 'a1234',
          jsonData: '{3723;.-\\||}',
        );
        final reader = AircraftDataReader(dataFile: badZipFile, urlFile: null);
        expect(await reader.validate(), false);
      },
    );

    test(
      'A zip file with an aircraft JSON file missing stuff should not pass validation',
      () async {
        final badZipFile = await _createAircraftFileWithData(
          filenameWithoutExtension: 'a1234',
          jsonData: '{"aircraft_id":"a1234","callsign":"A-1234"}',
        );
        final reader = AircraftDataReader(dataFile: badZipFile, urlFile: null);
        expect(await reader.validate(), false);
      },
    );

    test(
      'A zip file with a valid aircraft JSON file but missing stuff should not pass validation',
      () async {
        final goodZipFile = await _createAircraftFileWithData(
          filenameWithoutExtension: 'a1234',
          jsonData: '''
{
  "admin": true,
  "aircraft_id": "a1234",
  "callsign": "A-1234",
  "backend_info": {
    "google_api_service_account": "BLABLABLA",
    "google_api_key": "API_KEY_NONE",
    "google_calendar_id": "NO_CALENDAR_MAN"
  },
  "pilot_names": [
    "Mike",
    "John",
    "Claudia",
    "Anna",
    "Simon"
  ],
  "location": {
    "name": "Fly Berlin",
    "latitude": 52.8844253,
    "longitude": 12.7143166,
    "timezone": "Europe/Berlin"
  }
}''',
        );
        final reader = AircraftDataReader(dataFile: goodZipFile, urlFile: null);
        expect(await reader.validate(), false);
      },
    );
  });

  group('Testing aircraft data file opening', () {
    setUp(() {
      PathProviderPlatform.instance = MockPathProviderPlatform();
    });
    tearDown(() {
      Directory(
        (PathProviderPlatform.instance as MockPathProviderPlatform).baseDir,
      ).deleteSync(recursive: true);
    });

    // TODO some tests for bad cases here would be nice

    test('Aircraft data should exist in temp directory after open', () async {
      final goodZipFile = await _createExampleValidAircraftData();
      final reader = AircraftDataReader(dataFile: goodZipFile, urlFile: null);
      final baseDir = await getTemporaryDirectory();
      final directory = Directory(path.join(baseDir.path, 'current_aircraft'));
      final actual = await reader.open();
      expect(actual.path, directory.path);
      expect(directory.existsSync(), true);
      expect(
        File(path.join(directory.path, 'aircraft.json')).existsSync(),
        true,
      );
      expect(
        File(path.join(directory.path, 'aircraft.jpg')).existsSync(),
        true,
      );
      expect(
        File(path.join(directory.path, 'avatar-anna.jpg')).existsSync(),
        true,
      );
      expect(
        File(path.join(directory.path, 'avatar-claudia.jpg')).existsSync(),
        true,
      );
      expect(
        File(path.join(directory.path, 'avatar-john.jpg')).existsSync(),
        true,
      );
      expect(
        File(path.join(directory.path, 'avatar-mike.jpg')).existsSync(),
        true,
      );
      expect(
        File(path.join(directory.path, 'avatar-simon.jpg')).existsSync(),
        true,
      );
    });

    test('Aircraft data should be stored as new aircraft', () async {
      final goodZipFile = await _createExampleValidAircraftData();
      final reader = AircraftDataReader(dataFile: goodZipFile, urlFile: null);
      await reader.open();
      final storedFile = await addAircraftDataFile(
        reader,
        'http://localhost/a1234.zip',
      );
      final baseDir =
          (PathProviderPlatform.instance as MockPathProviderPlatform).baseDir;
      final actualPath = path.join(
        baseDir,
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
        final goodZipFile = await _createExampleValidAircraftData();
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
        expect(directory.existsSync(), true);
        expect(
          File(path.join(directory.path, 'aircraft.json')).existsSync(),
          true,
        );
        expect(
          File(path.join(directory.path, 'aircraft.jpg')).existsSync(),
          true,
        );
        expect(
          File(path.join(directory.path, 'avatar-anna.jpg')).existsSync(),
          true,
        );
        expect(
          File(path.join(directory.path, 'avatar-claudia.jpg')).existsSync(),
          true,
        );
        expect(
          File(path.join(directory.path, 'avatar-john.jpg')).existsSync(),
          true,
        );
        expect(
          File(path.join(directory.path, 'avatar-mike.jpg')).existsSync(),
          true,
        );
        expect(
          File(path.join(directory.path, 'avatar-simon.jpg')).existsSync(),
          true,
        );
      },
    );
  });

  group('Testing aircraft data download utilities', () {
    setUp(() {
      PathProviderPlatform.instance = MockPathProviderPlatform();
    });
    tearDown(() {
      final directory = Directory(
        (PathProviderPlatform.instance as MockPathProviderPlatform).baseDir,
      );
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
    });

    test('Aircraft data valid download', () async {
      final downloadProvider = MockDownloadProvider();
      const url = 'http://localhost/a1234.zip';
      final aircraftFile = await _createExampleValidAircraftData();
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
      final actual = aircraftData.dataPath!;
      expect(actual.path, directory.path);
      expect(directory.existsSync(), true);
      expect(
        File(path.join(directory.path, 'aircraft.json')).existsSync(),
        true,
      );
      expect(
        File(path.join(directory.path, 'aircraft.jpg')).existsSync(),
        true,
      );
      expect(
        File(path.join(directory.path, 'avatar-anna.jpg')).existsSync(),
        true,
      );
      expect(
        File(path.join(directory.path, 'avatar-claudia.jpg')).existsSync(),
        true,
      );
      expect(
        File(path.join(directory.path, 'avatar-john.jpg')).existsSync(),
        true,
      );
      expect(
        File(path.join(directory.path, 'avatar-mike.jpg')).existsSync(),
        true,
      );
      expect(
        File(path.join(directory.path, 'avatar-simon.jpg')).existsSync(),
        true,
      );
    });

    test(
      'Aircraft data invalid (JSON schema not validated) download',
      () async {
        final downloadProvider = MockDownloadProvider();
        const url = 'http://localhost/a1234.zip';
        final aircraftFile = await _createExampleWithInvalidJsonAircraftData();
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
      final aircraftFile =
          await _createExampleWithValidJSONAndMissingFilesAircraftData();
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

Future<File> _createExampleValidAircraftData() {
  return _createAircraftFileWithData(
    filenameWithoutExtension: 'a1234',
    jsonData: '''
{
  "admin": true,
  "aircraft_id": "a1234",
  "callsign": "A-1234",
  "backend_info": {
    "google_api_service_account": "BLABLABLA",
    "google_api_key": "API_KEY_NONE",
    "google_calendar_id": "NO_CALENDAR_MAN"
  },
  "pilot_names": [
    "Mike",
    "John",
    "Claudia",
    "Anna",
    "Simon"
  ],
  "location": {
    "name": "Fly Berlin",
    "latitude": 52.8844253,
    "longitude": 12.7143166,
    "timezone": "Europe/Berlin"
  }
}''',
    aircraftPicData: List<int>.filled(1000, 0x0A),
    pilotAvatarsPicData: {
      "anna": List<int>.filled(1000, 0x0A),
      "claudia": List<int>.filled(1000, 0x0A),
      "john": List<int>.filled(1000, 0x0A),
      "mike": List<int>.filled(1000, 0x0A),
      "simon": List<int>.filled(1000, 0x0A),
    },
  );
}

Future<File> _createExampleWithInvalidJsonAircraftData() {
  return _createAircraftFileWithData(
    filenameWithoutExtension: 'a1234',
    jsonData: '''
{
  "backend_info": {
    "google_api_service_account": "BLABLABLA",
    "google_api_key": "API_KEY_NONE",
    "google_calendar_id": "NO_CALENDAR_MAN"
  },
}''',
    aircraftPicData: List<int>.filled(1000, 0x0A),
    pilotAvatarsPicData: {
      "anna": List<int>.filled(1000, 0x0A),
      "claudia": List<int>.filled(1000, 0x0A),
      "john": List<int>.filled(1000, 0x0A),
      "mike": List<int>.filled(1000, 0x0A),
      "simon": List<int>.filled(1000, 0x0A),
    },
  );
}

Future<File> _createExampleWithValidJSONAndMissingFilesAircraftData() {
  return _createAircraftFileWithData(
    filenameWithoutExtension: 'a1234',
    jsonData: '''
{
  "admin": true,
  "aircraft_id": "a1234",
  "callsign": "A-1234",
  "backend_info": {
    "google_api_service_account": "BLABLABLA",
    "google_api_key": "API_KEY_NONE",
    "google_calendar_id": "NO_CALENDAR_MAN"
  },
  "pilot_names": [
    "Mike",
    "John",
    "Claudia",
    "Anna",
    "Simon"
  ],
  "location": {
    "name": "Fly Berlin",
    "latitude": 52.8844253,
    "longitude": 12.7143166,
    "timezone": "Europe/Berlin"
  }
}''',
    aircraftPicData: null,
    pilotAvatarsPicData: null,
  );
}

Future<File> _createAircraftFileWithData({
  required String filenameWithoutExtension,
  String? jsonData,
  List<int>? aircraftPicData,
  Map<String, List<int>>? pilotAvatarsPicData,
}) async {
  final tmpDir = await getTemporaryDirectory();
  tmpDir.createSync(recursive: true);
  final zipFile = File(path.join(tmpDir.path, '$filenameWithoutExtension.zip'));

  final encoder = ZipEncoder();
  final zipOutput = OutputFileStream(zipFile.path);
  encoder.startEncode(zipOutput);

  if (jsonData != null) {
    encoder.add(
      ArchiveFile.stream(
        'aircraft.json',
        InputMemoryStream(jsonData.codeUnits, length: jsonData.length),
      ),
    );
  }
  if (aircraftPicData != null) {
    encoder.add(
      ArchiveFile.stream('aircraft.jpg', InputMemoryStream(aircraftPicData)),
    );
  }
  if (pilotAvatarsPicData != null) {
    pilotAvatarsPicData.forEach((name, picData) {
      encoder.add(
        ArchiveFile.stream('avatar-$name.jpg', InputMemoryStream(picData)),
      );
    });
  }

  encoder.endEncode();
  zipOutput.close();

  return zipFile;
}

class MockPathProviderPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  // FIXME not really deterministic
  final String baseDir = '.testdata${Random().nextInt(1000)}';

  @override
  Future<String> getTemporaryPath() async {
    return path.join(baseDir, 'temp');
  }

  @override
  Future<String> getApplicationSupportPath() async {
    return path.join(baseDir, 'appdata');
  }

  @override
  Future<String> getLibraryPath() async {
    return path.join(baseDir, 'lib');
  }

  @override
  Future<String> getApplicationDocumentsPath() async {
    return path.join(baseDir, 'docs');
  }

  @override
  Future<String> getExternalStoragePath() async {
    return path.join(baseDir, 'ext');
  }

  @override
  Future<List<String>> getExternalCachePaths() async {
    return [];
  }

  @override
  Future<String> getDownloadsPath() async {
    return path.join(baseDir, 'download');
  }
}
