import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzData;
import 'package:timezone/standalone.dart' as tz;

import 'aircraft_data.dart';

class AppConfig {

  late SharedPreferences _prefs;

  AircraftData? _currentAircraft;

  init() async {
    _prefs = await SharedPreferences.getInstance();

    if (_currentAircraftId != null) {
      // load current aircraft
      // TODO error handling
      final aircraftReader = await loadAircraft(_currentAircraftId!);
      currentAircraft = aircraftReader.toAircraftData();
    }

    tzData.initializeTimeZones();
  }

  bool get admin {
    return _currentAircraft!.admin;
  }

  String get googleServiceAccountJson {
    return _currentAircraft!.backendInfo['google_api_service_account']!;
  }

  String get googleApiKey {
    return _currentAircraft!.backendInfo['google_api_key']!;
  }

  String get googleCalendarId {
    return _currentAircraft!.backendInfo['google_calendar_id']!;
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

  // TODO handle non-pilot user "(prove tecniche)"
  List<String> get pilotNames {
    return _currentAircraft!.pilotNames;
  }

  ImageProvider getPilotAvatar(String name) {
    return FileImage(_currentAircraft!.getPilotAvatar(name));
  }

  String? get _currentAircraftId {
    return _prefs.getString('currentAircraft');
  }

  set _currentAircraftId(String? value) {
    if (value != null) {
      _prefs.setString('currentAircraft', value);
    }
    else {
      _prefs.remove('currentAircraft');
    }
  }

  AircraftData? get currentAircraft => this._currentAircraft;

  set currentAircraft(AircraftData? data) {
    if (data != null) {
      print('Switching aircraft: ' + data.callSign);
    }
    else {
      print('Selecting no aircraft');
    }
    this._currentAircraft = data;
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
    return _prefs.getString('pilotName');
  }

  set pilotName(String? value) {
    if (value != null) {
      _prefs.setString('pilotName', value);
    }
    else {
      _prefs.remove('pilotName');
    }
  }

}
