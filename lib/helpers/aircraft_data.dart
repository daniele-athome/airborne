import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class AircraftData {
  final Directory? dataPath;
  final String id;
  final String callSign;
  final Map<String, dynamic> backendInfo;
  final List<String> pilotNames;
  final double locationLatitude;
  final double locationLongitude;
  final String locationTimeZone;
  final bool admin;

  AircraftData({
    required this.dataPath,
    required this.id,
    required this.callSign,
    required this.backendInfo,
    required this.pilotNames,
    required this.locationLatitude,
    required this.locationLongitude,
    required this.locationTimeZone,
    this.admin = false,
  });

  File getPilotAvatar(String name) {
    return File(path.join(this.dataPath!.path, 'avatar-' + name.toLowerCase() + '.jpg'));
  }

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
    if (metadata != null && metadata!['path'] != null) {
      return metadata!['path'];
    }

    final baseDir = await getTemporaryDirectory();
    final directory = Directory(path.join(baseDir.path, 'aircrafts', path.basenameWithoutExtension(dataFile.path)));
    final exists = await directory.exists();
    if (!exists) {
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
    }

    try {
      final jsonFile = File(path.join(directory.path, 'aircraft.json'));
      final jsonData = await jsonFile.readAsString();
      metadata = json.decode(jsonData) as Map<String, dynamic>;
    }
    catch(e) {
      print('aircraft.json is not valid JSON: ' + e.toString());
      throw FormatException('Not a valid aircraft archive.');
    }

    // aircraft picture
    final aircraftPicFile = File(path.join(directory.path, 'aircraft.jpg'));
    if (!(await aircraftPicFile.exists())) {
      print('aircraft.jpg is missing');
      throw FormatException('Not a valid aircraft archive.');
    }

    // pilot avatars
    for (var pilot in List<String>.from(metadata!['pilot_names'])) {
      if (!(await File(path.join(directory.path, 'avatar-' + pilot.toLowerCase() + '.jpg')).exists())) {
        print('pilot avatar for ' + pilot + ' is missing');
        throw FormatException('Not a valid aircraft archive.');
      }
    }

    // store path for later use
    metadata!['path'] = directory;
    return directory;
  }

  AircraftData toAircraftData() {
    return AircraftData(
      dataPath: metadata!['path'],
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
  final directory = Directory(path.join(baseDir.path, 'aircrafts'));
  await directory.create(recursive: true);
  final filename = path.join(directory.path, reader.metadata!['aircraft_id'] + '.zip');
  await deleteAircraftCache(reader.metadata!['aircraft_id']);
  return reader.dataFile.copy(filename);
}

/// Loads an aircraft data file into the cache.
Future<AircraftDataReader> loadAircraft(String aircraftId) async {
  final baseDir = await getApplicationSupportDirectory();
  final dataFile = File(path.join(baseDir.path, 'aircrafts', aircraftId + '.zip'));
  final reader = AircraftDataReader(dataFile: dataFile);
  await reader.open();
  return reader;
}

Future<Directory> deleteAircraftCache(String aircraftId) async {
  final cacheDir = await getTemporaryDirectory();
  final tmpDirectory = Directory(path.join(cacheDir.path, 'aircrafts', aircraftId));
  final exists = await tmpDirectory.exists();
  return exists ? tmpDirectory.delete(recursive: true) as Future<Directory> : Future.value(tmpDirectory);
}

Future<Directory> deleteAllAircrafts() async {
  // delete cache
  final cacheDir = await getTemporaryDirectory();
  final tmpDirectory = Directory(path.join(cacheDir.path, 'aircrafts'));
  if (await tmpDirectory.exists()) {
    await tmpDirectory.delete(recursive: true);
  }
  // delete files
  final baseDir = await getApplicationSupportDirectory();
  final directory = Directory(path.join(baseDir.path, 'aircrafts'));
  final exists = await directory.exists();
  return exists ? directory.delete(recursive: true) as Future<Directory> : Future.value(directory);
}
