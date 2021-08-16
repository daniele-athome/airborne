import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class AircraftData {
  final String id;
  final String callSign;
  final Map<String, dynamic> backendInfo;
  final List<String> pilotNames;
  final double locationLatitude;
  final double locationLongitude;
  final String locationTimeZone;
  final bool admin;

  AircraftData({
    required this.id,
    required this.callSign,
    required this.backendInfo,
    required this.pilotNames,
    required this.locationLatitude,
    required this.locationLongitude,
    required this.locationTimeZone,
    this.admin = false,
  });

}

class AircraftDataReader {
  final File dataFile;

  Map<String, dynamic>? metadata;

  AircraftDataReader({
    required this.dataFile,
  });

  /// Also loads metadata.
  Future<bool> validate() async {
    // FIXME in-memory operations - fine for small files, but it needs to change
    final bytes = await this.dataFile.readAsBytes();
    final archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    }
    catch (e) {
      print('Not a valid zip file: ' + e.toString());
      return false;
    }

    final mainFile = archive.findFile("aircraft.json");
    if (mainFile == null || !mainFile.isFile) {
      print('aircraft.json not found in archive!');
      return false;
    }

    final jsonData = mainFile.content as List<int>;
    final Map<String, dynamic> metadata;
    try {
      metadata = json.decode(String.fromCharCodes(jsonData)) as Map<String, dynamic>;
    }
    catch(e) {
      print('aircraft.json is not valid JSON: ' + e.toString());
      return false;
    }

    print(metadata);
    // TODO JSON Schema validation
    if (metadata['aircraft_id'] != null && metadata['callsign'] != null &&
        metadata['backend_info'] != null && metadata['pilot_names'] != null) {

      // TODO check for aircraft picture
      // TODO check for pilot avatars

      this.metadata = metadata;
      return true;
    }

    return false;
  }

  /// Opens an aircraft data file and extract contents in a temporary directory.
  Future<Directory> open() async {
    final baseDir = await getTemporaryDirectory();
    final directory = Directory(path.join(baseDir.path, 'aircrafts', path.basenameWithoutExtension(dataFile.path)));
    await directory.create(recursive: true);

    // FIXME in-memory operations - fine for small files, but it needs to change
    final bytes = await this.dataFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);

    for (final file in archive.files) {
      if (!file.isFile) {
        continue;
      }
      final f = File(path.join(directory.path, file.name));
      await f.writeAsBytes(file.content as List<int>);
    }

    // TODO really?
    final valid = await validate();
    if (!valid) {
      throw FormatException('Not a valid aircraft archive.');
    }

    return directory;
  }

  AircraftData toAircraftData() {
    return AircraftData(
      id: metadata!['aircraft_id'],
      callSign: metadata!['callsign'],
      backendInfo: metadata!['backend_info'],
      pilotNames: List<String>.from(metadata!['pilot_names']),
      locationLatitude: metadata!['location']?['latitude'],
      locationLongitude: metadata!['location']?['longitude'],
      locationTimeZone: metadata!['location']?['timezone'],
      admin: metadata!['admin'] != null ? metadata!['admin'] : false,
    );
  }

}

/// Add an aircraft data file to a local data store for long-term storage.
Future<File> addAircraftDataFile(AircraftDataReader reader) async {
  final baseDir = await getApplicationSupportDirectory();
  final directory = Directory(baseDir.path + '/aircrafts');
  await directory.create(recursive: true);
  final filename = directory.path + '/' + reader.metadata!['aircraft_id'] + '.zip';
  return reader.dataFile.copy(filename);
}

/// Loads an aircraft data file into the cache.
Future<AircraftDataReader> loadAircraft(String aircraftId) async {
  final baseDir = await getApplicationSupportDirectory();
  final dataFile = File(baseDir.path + '/aircrafts/' + aircraftId + '.zip');
  final reader = AircraftDataReader(dataFile: dataFile);
  await reader.open();
  return reader;
}
