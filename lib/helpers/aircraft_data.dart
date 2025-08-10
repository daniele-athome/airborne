import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:json_schema/json_schema.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'utils.dart';

final Logger _log = Logger((AircraftData).toString());

const _kAircraftMetadataFilename = 'aircraft.json';
const _kAircraftPicFilename = 'aircraft.jpg';

class AircraftData {
  /// File system path of the uncompressed archive.
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
  final String? locationWeatherLive;
  final String? locationWeatherForecast;
  final String? documentsArchive;
  final bool admin;

  /// The URL the aircraft data archive was originally downloaded from.
  final String? url;

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
    required this.locationWeatherLive,
    required this.locationWeatherForecast,
    required this.documentsArchive,
    required this.url,
    this.admin = false,
  });

  File getPilotAvatar(String name) {
    return File(path.join(dataPath!.path, 'avatar-${name.toLowerCase()}.jpg'));
  }

  File get aircraftPicture {
    return File(path.join(dataPath!.path, _kAircraftPicFilename));
  }
}

// TODO this class should be split into interface + 2 implementations, one file-based and one buffer-based
class AircraftDataReader {
  // for main constructor
  File? dataFile;
  File? urlFile;

  // for fromBytes constructor
  Uint8List? dataBytes;
  String? dataFilename;
  String? url;

  String? password;

  Map<String, dynamic>? metadata;

  AircraftDataReader({
    required this.dataFile,
    required this.urlFile,
    this.password,
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
      archive =
          ZipDecoder().decodeBytes(bytes, password: password, verify: true);
    } catch (e) {
      _log.warning('Not a valid zip file: $e');
      return false;
    }

    final mainFile = archive.findFile(_kAircraftMetadataFilename);
    if (mainFile == null || !mainFile.isFile) {
      _log.warning('$_kAircraftMetadataFilename not found in archive!');
      return false;
    }

    final jsonData = mainFile.content as List<int>;
    final Map<String, dynamic> metadata;
    try {
      metadata =
          json.decode(String.fromCharCodes(jsonData)) as Map<String, dynamic>;
    } catch (e) {
      _log.warning('$_kAircraftMetadataFilename is not valid JSON: $e');
      return false;
    }

    _log.finest(metadata);

    final schemaData =
        await rootBundle.loadString('assets/aircraft.schema.json');
    final schema = JsonSchema.create(schemaData);
    final validation = schema.validate(metadata);
    if (validation.isValid) {
      // aircraft picture
      final aircraftPic = archive.findFile(_kAircraftPicFilename);
      if (aircraftPic == null || !aircraftPic.isFile) {
        _log.warning('$_kAircraftPicFilename not found in archive!');
        return false;
      }

      // pilot avatars
      for (final pilot
          in List<String>.from(metadata['pilot_names'] as Iterable<dynamic>)) {
        final avatarPic = archive.findFile('avatar-${pilot.toLowerCase()}.jpg');
        if (avatarPic == null || !avatarPic.isFile) {
          _log.warning('pilot avatar for $pilot is missing');
          return false;
        }
      }

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
      final bytes =
          dataFile != null ? await dataFile!.readAsBytes() : dataBytes!;
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
      final jsonFile =
          File(path.join(directory.path, _kAircraftMetadataFilename));
      final jsonData = await jsonFile.readAsString();
      metadata = json.decode(jsonData) as Map<String, dynamic>;
    } catch (e) {
      _log.warning('$_kAircraftMetadataFilename is not valid JSON: $e');
      throw const FormatException('Not a valid aircraft archive.');
    }

    // aircraft picture
    final aircraftPicFile =
        File(path.join(directory.path, _kAircraftPicFilename));
    if (!(await aircraftPicFile.exists())) {
      _log.warning('$_kAircraftPicFilename is missing');
      throw const FormatException('Not a valid aircraft archive.');
    }

    // pilot avatars
    for (final pilot
        in List<String>.from(metadata!['pilot_names'] as Iterable<dynamic>)) {
      if (!(await File(
              path.join(directory.path, 'avatar-${pilot.toLowerCase()}.jpg'))
          .exists())) {
        _log.warning('pilot avatar for $pilot is missing');
        throw const FormatException('Not a valid aircraft archive.');
      }
    }

    // try to open url file if available
    try {
      String? url = urlFile != null ? await urlFile!.readAsString() : this.url;
      metadata!['url'] = url;
    } catch (e) {
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
        pilotNames:
            List<String>.from(metadata!['pilot_names'] as Iterable<dynamic>),
        noPilotName: metadata!['no_pilot_name'] as String?,
        locationName: metadata!['location']?['name'] as String,
        locationLatitude: metadata!['location']?['latitude'] as double,
        locationLongitude: metadata!['location']?['longitude'] as double,
        locationTimeZone: metadata!['location']?['timezone'] as String,
        locationWeatherLive: metadata!['location']?['weather_live'] as String?,
        locationWeatherForecast:
            metadata!['location']?['weather_forecast'] as String?,
        documentsArchive: metadata!['documents_archive'] as String?,
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
  File urlFile = File(path.join(
      directory.path, '${reader.metadata!['aircraft_id'] as String}.url'));
  await urlFile.writeAsString(url);
  reader.urlFile = urlFile;

  // decrypt and save again
  final filename = path.join(
      directory.path, '${reader.metadata!['aircraft_id'] as String}.zip');
  return decryptDataFile(reader.dataFile!.path, reader.password, filename);
}

/// Decrypts a zip file and stores it unencrypted to another file.
Future<File> decryptDataFile(String encryptedFilename, String? password,
    String decryptedFilename) async {
  final Archive encryptedArchive = ZipDecoder().decodeBytes(
      await File(encryptedFilename).readAsBytes(),
      password: password,
      verify: true);
  final Archive decryptedArchive = Archive();

  for (final inFile in encryptedArchive.files) {
    if (!inFile.isFile) {
      continue;
    }

    final outFile = ArchiveFile(inFile.name, inFile.size, inFile.content);
    decryptedArchive.add(outFile);
  }

  final decryptedBytes =
      ZipEncoder().encodeBytes(decryptedArchive, level: DeflateLevel.bestSpeed);
  return await File(decryptedFilename).writeAsBytes(decryptedBytes);
}

/// Loads an aircraft data file into the cache.
Future<AircraftDataReader> loadAircraft(String aircraftId) async {
  final baseDir = await getApplicationSupportDirectory();
  final dataFile =
      File(path.join(baseDir.path, 'aircrafts', '$aircraftId.zip'));
  final urlFile = File(path.join(baseDir.path, 'aircrafts', '$aircraftId.url'));
  // null password because the cached zip file is unencrypted
  final reader = AircraftDataReader(dataFile: dataFile, urlFile: urlFile);
  await reader.open();
  return reader;
}

Future<Directory> deleteAircraftCache() async {
  final cacheDir = await getTemporaryDirectory();
  final tmpDirectory = Directory(path.join(cacheDir.path, 'current_aircraft'));
  final exists = await tmpDirectory.exists();
  return exists
      ? tmpDirectory.delete(recursive: true) as Future<Directory>
      : Future.value(tmpDirectory);
}

class AircraftBadFileException implements Exception {}

class AircraftValidationException implements Exception {}

class AircraftStoreException implements Exception {
  final Object cause;

  AircraftStoreException(this.cause);
}

Future<AircraftData> _validateAndStoreAircraft(
    File file, String url, String? password) async {
  try {
    final encryptedReader =
        AircraftDataReader(dataFile: file, urlFile: null, password: password);
    final validation = await encryptedReader.validate();
    _log.finest('VALIDATION: $validation');

    if (validation) {
      // the returned file will be decrypted
      final dataFile = await addAircraftDataFile(encryptedReader, url);
      _log.finest(dataFile);

      await deleteAircraftCache();

      // open up a new reader for the unencrypted file
      final reader = AircraftDataReader(
          dataFile: dataFile, urlFile: encryptedReader.urlFile);
      await reader.open();
      return reader.toAircraftData();
    } else {
      return Future.error(AircraftValidationException());
    }
  } on FormatException catch (_) {
    _log.warning('Error reading aircraft data file, wrong password?');
    return Future.error(AircraftBadFileException());
  } catch (e, stacktrace) {
    _log.warning('Error storing aircraft data file', e, stacktrace);
    return Future.error(AircraftStoreException(e), stacktrace);
  }
}

Future<AircraftData> downloadAircraftData(
    String url, String? userpass, DownloadProvider downloadProvider) async {
  String? username;
  String? password;
  if (userpass != null && userpass.isNotEmpty) {
    final separator = userpass.indexOf(':');
    if (separator >= 0) {
      username = userpass.substring(0, separator);
      password = userpass.substring(separator + 1);
    }
  }
  return downloadProvider
      .downloadToFile(url, 'aircraft.zip', username, password, true)
      .timeout(kNetworkRequestTimeout)
      .then((tempfile) async {
    _log.finest(tempfile);
    final stored = await _validateAndStoreAircraft(tempfile, url, userpass);
    tempfile.deleteSync();
    return stored;
  });
}
