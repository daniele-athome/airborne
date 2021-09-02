import 'dart:io';
import 'dart:math';

import 'package:airborne/helpers/aircraft_data.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:test/test.dart';

import '../test_init.dart';

void main() {
  testInit();

  test('A corrupted zip file should not pass validation', () async {
    final tmpDir = await getTemporaryDirectory();
    final badZipFile = File(path.join(tmpDir.path, 'aircraft_test_${Random().nextInt(1000)}.zip'));
    // damaged zip
    badZipFile.writeAsStringSync("PK###BAD ZIP FILE");
    final reader = AircraftDataReader(dataFile: badZipFile);
    expect(await reader.validate(), false);
  });

  test('A zip file with an invalid aircraft JSON file should not pass validation', () async {
    final badZipFile = await _createAircraftFileWithData(jsonData: '{3723;.-\\||}');
    final reader = AircraftDataReader(dataFile: badZipFile);
    expect(await reader.validate(), false);
  });

  test('A zip file with an aircraft JSON file missing stuff should not pass validation', () async {
    final badZipFile = await _createAircraftFileWithData(jsonData: '{"aircraft_id":"a1234","callsign":"A-1234"}');
    final reader = AircraftDataReader(dataFile: badZipFile);
    expect(await reader.validate(), false);
  });

  test('A zip file with a valid aircraft JSON file should pass validation', () async {
    final badZipFile = await _createAircraftFileWithData(jsonData: '''
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
    "latitude": 52.8844253,
    "longitude": 12.7143166,
    "timezone": "Europe/Berlin"
  }
}''');
    final reader = AircraftDataReader(dataFile: badZipFile);
    expect(await reader.validate(), true);
  });

  // TODO other bad cases (e.g. missing pilot avatars, missing backend_info (which one?), missing aircraft picture)
}

Future<File> _createAircraftFileWithData({
    String? jsonData,
    List<int>? aircraftPicData,
    Map<String, List<int>>? pilotAvatarsPicData,
  }) async {
  final tmpDir = await getTemporaryDirectory();
  final zipFile = File(path.join(tmpDir.path, 'aircraft_test_${Random().nextInt(1000)}.zip'));

  final encoder = ZipEncoder();
  encoder.startEncode(OutputFileStream(zipFile.path));

  if (jsonData != null) {
    encoder.addFile(ArchiveFile.stream(
        'aircraft.json', jsonData.length, InputStream(jsonData.codeUnits)));
  }
  if (aircraftPicData != null) {
    encoder.addFile(ArchiveFile.stream(
        'aircraft.jpg', aircraftPicData.length, InputStream(aircraftPicData)));
  }
  if (pilotAvatarsPicData != null) {
    pilotAvatarsPicData.forEach((name, picData) {
      encoder.addFile(ArchiveFile.stream(
          'avatar-$name.jpg', picData.length, InputStream(picData)));
    });
  }

  encoder.endEncode();

  return zipFile;
}
