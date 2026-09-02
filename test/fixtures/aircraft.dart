import 'dart:convert';
import 'dart:io';

import 'package:airborne/helpers/aircraft_data.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

const kSampleAircraftId = 'a1234';
const kSampleCallSign = 'A-1234';
const kSamplePilotNames = ['Mike', 'John', 'Claudia', 'Anna', 'Simon'];

const kSampleBackendInfo = <String, dynamic>{
  'google_api_service_account': 'BLABLABLA',
  'google_api_key': 'API_KEY_NONE',
  'google_calendar_id': 'NO_CALENDAR_MAN',
};

/// Placeholder bytes for the aircraft picture and the pilot avatars.
List<int> samplePictureData() => List<int>.filled(1000, 0x0A);

/// Builds an `aircraft.json` payload, per `assets/aircraft.schema.json`.
Map<String, dynamic> aircraftMetadata({
  String aircraftId = kSampleAircraftId,
  String callSign = kSampleCallSign,
  bool admin = true,
  Map<String, dynamic> backendInfo = kSampleBackendInfo,
  List<String> pilotNames = kSamplePilotNames,
  String? noPilotName,
  int? hourmeterMultiplier,
  String locationName = 'Fly Berlin',
  double latitude = 52.8844253,
  double longitude = 12.7143166,
  String timeZone = 'Europe/Berlin',
}) => <String, dynamic>{
  'admin': admin,
  'aircraft_id': aircraftId,
  'callsign': callSign,
  'backend_info': backendInfo,
  'pilot_names': pilotNames,
  'no_pilot_name': ?noPilotName,
  'hourmeter_multiplier': ?hourmeterMultiplier,
  'location': {
    'name': locationName,
    'latitude': latitude,
    'longitude': longitude,
    'timezone': timeZone,
  },
};

/// Writes an aircraft archive in the temporary directory.
///
/// Any part can be left out to build a deliberately broken archive. Requires a
/// path provider fake to be installed (see `useFakePathProvider`).
Future<File> createAircraftZipFile({
  String filenameWithoutExtension = kSampleAircraftId,
  String? jsonData,
  List<int>? aircraftPicData,
  Map<String, List<int>>? pilotAvatarsPicData,
  String? password,
}) async {
  final tmpDir = await getTemporaryDirectory();
  tmpDir.createSync(recursive: true);
  final zipFile = File(path.join(tmpDir.path, '$filenameWithoutExtension.zip'));

  final encoder = ZipEncoder(password: password);
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

/// Writes a complete, schema-valid aircraft archive, with an avatar for every
/// name in `pilot_names`.
Future<File> createValidAircraftZipFile({
  Map<String, dynamic>? metadata,
  String? password,
}) {
  final data = metadata ?? aircraftMetadata();
  final pilotNames = List<String>.from(data['pilot_names'] as List);
  return createAircraftZipFile(
    filenameWithoutExtension: data['aircraft_id'] as String,
    jsonData: json.encode(data),
    aircraftPicData: samplePictureData(),
    pilotAvatarsPicData: {
      for (final name in pilotNames) name.toLowerCase(): samplePictureData(),
    },
    password: password,
  );
}

/// Opens a valid archive and returns the resulting [AircraftData], with the
/// pictures actually present on disk.
///
/// Clears the extraction cache first, the way `_validateAndStoreAircraft` does:
/// [AircraftDataReader.open] only unpacks when `current_aircraft` is missing,
/// so without this a second call would hand back the first aircraft.
Future<AircraftData> createSampleAircraftData({
  Map<String, dynamic>? metadata,
}) async {
  final zipFile = await createValidAircraftZipFile(metadata: metadata);
  await deleteAircraftCache();
  final reader = AircraftDataReader(dataFile: zipFile, urlFile: null);
  await reader.open();
  return reader.toAircraftData();
}
