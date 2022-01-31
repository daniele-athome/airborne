import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:json_schema2/json_schema2.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'utils.dart';

final Logger _log = Logger((AircraftData).toString());

class AircraftData {
  final Directory? dataPath;
  final String id;
  final String callSign;
  final Map<String, dynamic> backendInfo;
  final List<String> pilotNames;
  final String? noPilotName;
  final String locationName;
  final double locationLatitude;
  final double locationLongitude;
  final String locationTimeZone;
  final Map<num, String>? fuelPrices;
  final String? url;
  final bool admin;

  AircraftData({
    required this.dataPath,
    required this.id,
    required this.callSign,
    required this.backendInfo,
    required this.pilotNames,
    required this.noPilotName,
    required this.locationName,
    required this.locationLatitude,
    required this.locationLongitude,
    required this.locationTimeZone,
    required this.fuelPrices,
    required this.url,
    this.admin = false,
  });

  File getPilotAvatar(String name) {
    return File(path.join(dataPath!.path, 'avatar-${name.toLowerCase()}.jpg'));
  }

  File get aircraftPicture {
    return File(path.join(dataPath!.path, 'aircraft.jpg'));
  }

}

class AircraftDataReader {
  // for main constructor
  File? dataFile;
  File? urlFile;
  // for fromBytes constructor
  Uint8List? dataBytes;
  String? dataFilename;
  String? url;

  Map<String, dynamic>? metadata;

  AircraftDataReader({
    required this.dataFile,
    required this.urlFile,
  });

  /// Mainly for integration testing.
  @visibleForTesting
  AircraftDataReader.fromBytes({
    required this.dataBytes,
    required this.dataFilename,
    required this.url,
  });

  /// Also loads metadata.
  Future<bool> validate() async {
    // FIXME in-memory operations - fine for small files, but it needs to change
    final bytes = dataFile != null ? await dataFile!.readAsBytes() : dataBytes!;
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    }
    catch (e) {
      _log.warning('Not a valid zip file: $e');
      return false;
    }

    final mainFile = archive.findFile("aircraft.json");
    if (mainFile == null || !mainFile.isFile) {
      _log.warning('aircraft.json not found in archive!');
      return false;
    }

    final jsonData = mainFile.content as List<int>;
    final Map<String, dynamic> metadata;
    try {
      metadata = json.decode(String.fromCharCodes(jsonData)) as Map<String, dynamic>;
    }
    catch(e) {
      _log.warning('aircraft.json is not valid JSON: $e');
      return false;
    }

    _log.finest(metadata);

    final schemaData = await rootBundle.loadString('assets/aircraft.schema.json');
    final schema = JsonSchema.createSchema(schemaData);
    if (schema.validate(metadata)) {
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
      return metadata!['path'] as Directory;
    }

    final baseDir = await getTemporaryDirectory();
    final directory = Directory(path.join(baseDir.path, 'current_aircraft'));
    final exists = await directory.exists();
    if (!exists) {
      await directory.create(recursive: true);

      // FIXME in-memory operations - fine for small files, but it needs to change
      final bytes = dataFile != null ? await dataFile!.readAsBytes() : dataBytes!;
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
      _log.warning('aircraft.json is not valid JSON: $e');
      throw const FormatException('Not a valid aircraft archive.');
    }

    // aircraft picture
    final aircraftPicFile = File(path.join(directory.path, 'aircraft.jpg'));
    if (!(await aircraftPicFile.exists())) {
      _log.warning('aircraft.jpg is missing');
      throw const FormatException('Not a valid aircraft archive.');
    }

    // pilot avatars
    for (final pilot in List<String>.from(metadata!['pilot_names'] as Iterable<dynamic>)) {
      if (!(await File(path.join(directory.path, 'avatar-${pilot.toLowerCase()}.jpg')).exists())) {
        _log.warning('pilot avatar for $pilot is missing');
        throw const FormatException('Not a valid aircraft archive.');
      }
    }

    // try to open url file if available
    try {
      String? url = urlFile != null ? await urlFile!.readAsString() : this.url;
      metadata!['url'] = url;
    }
    catch (e) {
      // fail gracefully
      _log.info("Unable to read url file", e);
    }

    // store path for later use
    metadata!['path'] = directory;
    return directory;
  }

  AircraftData toAircraftData() => AircraftData(
      dataPath: metadata!['path'] as Directory,
      id: metadata!['aircraft_id'] as String,
      callSign: metadata!['callsign'] as String,
      backendInfo: metadata!['backend_info'] as Map<String, dynamic>,
      pilotNames: List<String>.from(metadata!['pilot_names'] as Iterable<dynamic>),
      noPilotName: metadata!['no_pilot_name'] as String?,
      locationName: metadata!['location']?['name'] as String,
      locationLatitude: metadata!['location']?['latitude'] as double,
      locationLongitude: metadata!['location']?['longitude'] as double,
      locationTimeZone: metadata!['location']?['timezone'] as String,
      fuelPrices: (metadata!['fuel_prices'] != null) ?
        Map.fromEntries((metadata!['fuel_prices'] as List<dynamic>).map((item) =>
          MapEntry((item as Map<String, dynamic>)['value'] as num, item['label'] as String))) : null,
      url: metadata!['url'] as String?,
      admin: metadata!['admin'] != null && metadata!['admin'] as bool,
    );

}

/// Add an aircraft data file to a local data store for long-term storage.
Future<File> addAircraftDataFile(AircraftDataReader reader, String url) async {
  if (reader.dataFile == null) {
    throw UnimplementedError('Running in a test??');
  }
  final baseDir = await getApplicationSupportDirectory();
  final directory = Directory(path.join(baseDir.path, 'aircrafts'));
  await directory.create(recursive: true);

  // store url in separate file
  File urlFile = File(path.join(directory.path, '${reader.metadata!['aircraft_id'] as String}.url'));
  await urlFile.writeAsString(url);
  reader.urlFile = urlFile;

  final filename = path.join(directory.path, '${reader.metadata!['aircraft_id'] as String}.zip');
  return reader.dataFile!.copy(filename);
}

/// Loads an aircraft data file into the cache.
Future<AircraftDataReader> loadAircraft(String aircraftId) async {
  final baseDir = await getApplicationSupportDirectory();
  final dataFile = File(path.join(baseDir.path, 'aircrafts', '$aircraftId.zip'));
  final urlFile = File(path.join(baseDir.path, 'aircrafts', '$aircraftId.url'));
  final reader = AircraftDataReader(
    dataFile: dataFile,
    urlFile: urlFile
  );
  await reader.open();
  return reader;
}

Future<Directory> deleteAircraftCache() async {
  final cacheDir = await getTemporaryDirectory();
  final tmpDirectory = Directory(path.join(cacheDir.path, 'current_aircraft'));
  final exists = await tmpDirectory.exists();
  return exists ? tmpDirectory.delete(recursive: true) as Future<Directory> : Future.value(tmpDirectory);
}

class AircraftValidationException implements Exception {
}

class AircraftStoreException implements Exception {
  final Object cause;

  AircraftStoreException(this.cause);
}

Future<AircraftData> _validateAndStoreAircraft(File file, String url) async {
  final reader = AircraftDataReader(dataFile: file, urlFile: null);
  final validation = await reader.validate();
  _log.finest('VALIDATION: $validation');
  if (validation) {
    try {
      final dataFile = await addAircraftDataFile(reader, url);
      _log.finest(dataFile);
      await deleteAircraftCache();
      await reader.open();
      final aircraftData = reader.toAircraftData();
      return aircraftData;
    }
    catch (e, stacktrace) {
      _log.warning('Error storing aircraft data file', e, stacktrace);
      return Future.error(AircraftStoreException(e), stacktrace);
    }
  }
  else {
    return Future.error(AircraftValidationException());
  }
}

Future<AircraftData> downloadAircraftData(String url, String? userpass, DownloadProvider downloadProvider) async {
  String? username;
  String? password;
  if (userpass != null && userpass.isNotEmpty) {
    final separator = userpass.indexOf(':');
    if (separator >= 0) {
      username = userpass.substring(0, separator);
      password = userpass.substring(separator + 1);
    }
  }
  return downloadProvider.downloadToFile(url, 'aircraft.zip', username, password, true)
      .timeout(kNetworkRequestTimeout)
      .then((tempfile) async {
    _log.finest(tempfile);
    final stored = await _validateAndStoreAircraft(tempfile, url);
    tempfile.deleteSync();
    return stored;
  });
}
