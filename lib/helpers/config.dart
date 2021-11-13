import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/standalone.dart' as tz;

import 'aircraft_data.dart';

final Logger _log = Logger((AppConfig).toString());

class AppConfig {

  @protected
  late SharedPreferences prefs;

  AircraftData? _currentAircraft;

  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();

    if (_currentAircraftId != null) {
      // load current aircraft
      try {
        final aircraftReader = await loadAircraft(_currentAircraftId!);
        currentAircraft = aircraftReader.toAircraftData();
      }
      catch (e) {
        _log.info('Error loading current aircraft, cleaning everything ($e)');
        _currentAircraftId = null;
        pilotName = null;
        // a bit drastic maybe...
        deleteAllAircrafts();
      }
    }
  }

  bool hasFeature(String feature) {
    switch (feature) {
      case 'book_flight':
        return _currentAircraft!.backendInfo['google_calendar_id'] != null;
      case 'flight_log':
        return _currentAircraft!.backendInfo['flightlog'] != null;
      default:
        throw Exception('Unknown feature: $feature');
    }
  }

  bool get admin {
    return _currentAircraft!.admin;
  }

  String get googleServiceAccountJson {
    return _currentAircraft!.backendInfo['google_api_service_account']! as String;
  }

  String get googleApiKey {
    return _currentAircraft!.backendInfo['google_api_key']! as String;
  }

  String get googleCalendarId {
    return _currentAircraft!.backendInfo['google_calendar_id']! as String;
  }

  Map<String, String> get flightlogBackendInfo {
    return (_currentAircraft!.backendInfo['flightlog'] as Map<String, dynamic>)
        .map((key, value) => MapEntry(key, value as String));
  }

  String get locationName {
    return _currentAircraft!.locationName;
  }

  double get locationLatitude {
    return _currentAircraft!.locationLatitude;
  }

  double get locationLongitude {
    return _currentAircraft!.locationLongitude;
  }

  tz.Location get locationTimeZone {
    return tz.getLocation(_currentAircraft!.locationTimeZone);
  }

  String get locationUrl {
    // TODO constant? Format? Whatever?
    return 'https://www.google.com/maps/search/?api=1&query=$locationLatitude,$locationLongitude';
  }

  // TODO handle non-pilot user "(prove tecniche)"
  List<String> get pilotNames {
    return _currentAircraft!.pilotNames;
  }

  ImageProvider getPilotAvatar(String name) {
    return FileImage(_currentAircraft!.getPilotAvatar(name));
  }

  ImageProvider get aircraftPicture {
    return FileImage(_currentAircraft!.aircraftPicture);
  }

  String? get _currentAircraftId {
    return prefs.getString('currentAircraft');
  }

  set _currentAircraftId(String? value) {
    if (value != null) {
      prefs.setString('currentAircraft', value);
    }
    else {
      prefs.remove('currentAircraft');
    }
  }

  AircraftData? get currentAircraft => _currentAircraft;

  set currentAircraft(AircraftData? data) {
    if (data != null) {
      _log.fine('Switching aircraft: ${data.callSign}');
    }
    else {
      // TODO maybe delete the temp folder?
      _log.fine('Selecting no aircraft');
    }
    _currentAircraft = data;
    _currentAircraftId = data?.id;
  }

  List<AircraftData> get aircrafts {
    // TODO
    return [];
  }

  void addAircraft(AircraftData data) {
    // TODO
  }

  void updateAircraft(AircraftData data) {
    // TODO
  }

  void removeAircraft(String id) {
    // TODO
  }

  String? get pilotName {
    return prefs.getString('pilotName');
  }

  set pilotName(String? value) {
    if (value != null) {
      prefs.setString('pilotName', value);
    }
    else {
      prefs.remove('pilotName');
    }
  }

}
