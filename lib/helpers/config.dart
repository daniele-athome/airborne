import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzData;
import 'package:timezone/standalone.dart' as tz;

class AppConfig {

  late String _googleServiceAccountJson;
  late SharedPreferences _prefs;

  init() async {
    _prefs = await SharedPreferences.getInstance();
    await dotenv.load(fileName: 'assets/data/.env');

    _googleServiceAccountJson =
        await rootBundle.loadString(dotenv.env['google_api_service_account']!);

    tzData.initializeTimeZones();
  }

  bool get admin {
    return dotenv.env['admin']!.toLowerCase() == 'true';
  }

  String get googleServiceAccountJson {
    return _googleServiceAccountJson;
  }

  String get googleApiKey {
    return dotenv.env['google_api_key']!;
  }

  String get googleCalendarId {
    return dotenv.env['google_calendar_id']!;
  }

  double get locationLatitude {
    return double.parse(dotenv.env['location_latitude']!);
  }

  double get locationLongitude {
    return double.parse(dotenv.env['location_longitude']!);
  }

  tz.Location get locationTimeZone {
    return tz.getLocation(dotenv.env['location_timezone']!);
  }

  // TODO handle non-pilot user "(prove tecniche)"
  List<String> get pilotNames {
    return dotenv.env['pilotNames']!.split(r',');
  }

  ImageProvider getPilotAvatar(String name) {
    return AssetImage('assets/data/avatar-' + name.toLowerCase() + '.jpg');
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
