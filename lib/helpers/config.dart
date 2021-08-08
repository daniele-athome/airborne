import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzData;
import 'package:timezone/standalone.dart' as tz;

class AppConfig {

  @deprecated
  late String _googleServiceAccountJson;
  late SharedPreferences _prefs;

  AircraftData? currentAircraft;

  init() async {
    _prefs = await SharedPreferences.getInstance();
    // TEMP
    await dotenv.load(fileName: 'assets/data/.env');
    _googleServiceAccountJson =
        await rootBundle.loadString(dotenv.env['google_api_service_account']!);
    currentAircraft = aircrafts![0];

    tzData.initializeTimeZones();
  }

  bool get admin {
    return currentAircraft!.admin;
  }

  String get googleServiceAccountJson {
    return currentAircraft!.backendInfo['google_api_service_account']!;
  }

  String get googleApiKey {
    return currentAircraft!.backendInfo['google_api_key']!;
  }

  String get googleCalendarId {
    return currentAircraft!.backendInfo['google_calendar_id']!;
  }

  double get locationLatitude {
    return currentAircraft!.locationLatitude;
  }

  double get locationLongitude {
    return currentAircraft!.locationLongitude;
  }

  tz.Location get locationTimeZone {
    return tz.getLocation(currentAircraft!.locationTimeZone);
  }

  // TODO handle non-pilot user "(prove tecniche)"
  List<String> get pilotNames {
    return currentAircraft!.pilotNames;
  }

  ImageProvider getPilotAvatar(String name) {
    // TODO load from files
    return AssetImage('assets/data/avatar-' + name.toLowerCase() + '.jpg');
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

  void switchAircraft(AircraftData data) {
    this.currentAircraft = data;
    _currentAircraftId = data.id;
  }

  List<AircraftData>? get aircrafts {
    // TODO

    return [
      AircraftData(
        id: dotenv.env['aircraft_id']!,
        callSign: dotenv.env['callsign']!,
        backendInfo: {
          'google_api_service_account': _googleServiceAccountJson,
          'google_api_key': dotenv.env['google_api_key']!,
          'google_calendar_id': dotenv.env['google_calendar_id']!,
        },
        pilotNames: dotenv.env['pilotNames']!.split(r','),
        locationLatitude: double.parse(dotenv.env['location_latitude']!),
        locationLongitude: double.parse(dotenv.env['location_longitude']!),
        locationTimeZone: dotenv.env['location_timezone']!,
        admin: dotenv.env['admin']!.toLowerCase() == 'true',
      )
    ];
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
