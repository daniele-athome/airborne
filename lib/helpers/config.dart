import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/standalone.dart' as tz;

import 'aircraft_data.dart';

final Logger _log = Logger((AppConfig).toString());

class AppConfig extends ChangeNotifier {

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
        deleteAircraftCache();
      }
    }
  }

  bool hasFeature(String feature) {
    if (_currentAircraft == null) {
      return false;
    }
    switch (feature) {
      case 'book_flight':
        return _currentAircraft!.backendInfo['google_calendar_id'] != null;
      case 'flight_log':
        return _currentAircraft!.backendInfo['flightlog_spreadsheet_id'] != null &&
            _currentAircraft!.backendInfo['flightlog_sheet_name'] != null &&
            _currentAircraft!.noPilotName != null;
      case 'activities':
        return _currentAircraft!.backendInfo['activities_spreadsheet_id'] != null &&
            _currentAircraft!.backendInfo['activities_sheet_name'] != null;
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
    return {
      'spreadsheet_id': _currentAircraft!.backendInfo['flightlog_spreadsheet_id'],
      'sheet_name': _currentAircraft!.backendInfo['flightlog_sheet_name'],
    };
  }

  Map<String, String> get activitiesBackendInfo {
    return {
      'spreadsheet_id': _currentAircraft!.backendInfo['activities_spreadsheet_id'],
      'sheet_name': _currentAircraft!.backendInfo['activities_sheet_name'],
    };
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

  Map<num, String>? get fuelPrices {
    return _currentAircraft!.fuelPrices;
  }

  // TODO read from configuration
  String get fuelPriceCurrency {
    return '€';
  }

  List<String> get pilotNames {
    return _currentAircraft!.pilotNames;
  }

  List<String> get pilotNamesWithNoPilot {
    return [_currentAircraft!.noPilotName!, ..._currentAircraft!.pilotNames];
  }

  String? get noPilotName {
    return _currentAircraft!.noPilotName;
  }

  ImageProvider getPilotAvatar(String name) {
    return (name == _currentAircraft!.noPilotName ?
      const AssetImage('assets/images/nopilot_avatar.png') :
      FileImage(_currentAircraft!.getPilotAvatar(name))) as ImageProvider;
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
      deleteAircraftCache();
      _log.fine('Selecting no aircraft');
    }
    if (_currentAircraft != null) {
      _clearPictureCache();
    }
    _currentAircraft = data;
    _currentAircraftId = data?.id;
    notifyListeners();
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
    notifyListeners();
  }

  num? get customFuelPrice {
    return prefs.getDouble("fuelPrice");
  }

  set customFuelPrice(num? price) {
    if (price != null) {
      prefs.setDouble("fuelPrice", price.toDouble());
    }
    else {
      prefs.remove("fuelPrice");
    }
  }

  /// True if fuel price should be asked as unit price (e.g. "I bought 14 liters at 2.5 € per liter"),
  /// false if total purchase price should be asked instead (e.g. "I bought 14 liters for 35 €")
  // TODO make it a configuration parameter
  bool get useFuelUnitPrice => false;

  void _clearPictureCache() {
    aircraftPicture.evict();
    for (var name in pilotNames) {
      getPilotAvatar(name).evict();
    }
  }

}
