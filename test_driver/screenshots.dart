import 'dart:math';

import 'package:airborne/helpers/aircraft_data.dart';
import 'package:airborne/helpers/config.dart';
import 'package:airborne/main.dart' as app;
import 'package:airborne/models/book_flight_models.dart';
import 'package:airborne/screens/pilot_select/pilot_select_screen.dart';
import 'package:airborne/services/book_flight_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:intl/intl_standalone.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_localizations/syncfusion_localizations.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart';

import 'screenshots_data.dart';

Future<void> main() async {
  enableFlutterDriverExtension();

  await findSystemLocale();
  tz_data.initializeTimeZones();
  final appConfig = FakeAppConfig();
  await appConfig.init();

  runApp(
    Provider<AppConfig>.value(
      value: appConfig,
      builder: (_, __) => const MainNavigationApp(),
    ),
  );
}

/// Generates some random events within the current month so they appear immediately.
List<FlightBooking> generateFakeEvents(List<String> pilotNames) {
  const startHour = 5;
  const endHour = 22;
  const fakeNotes = <String>[
    'Elba',
    'Roundtrip NYC',
    'LIRU',
    'London Heathrow',
    'Flight school',
    'Anyone with me?',
  ];
  
  final now = DateTime.now();
  // matches with the one in the zip file
  final location = getLocation('Europe/Rome');
  final startDate = TZDateTime.from(DateTime(now.year, now.month, now.day), location).subtract(const Duration(days: 30));
  final endDate = TZDateTime.from(DateTime(now.year, now.month, now.day), location).add(const Duration(days: 30));
  TZDateTime currentDate = startDate;
  final events = <FlightBooking>[];
  final random = Random();
  while (currentDate.isBefore(endDate)) {
    // 40% chance of having events on any given day
    final numEvents = random.nextInt(100 ~/ 40) == 0 ? (random.nextInt(4) + 1) : 0;
    int currentHour = startHour;
    int numDayEvents = 0;
    while (currentHour < endHour && numDayEvents < numEvents) {
      int eventHours;
      do {
        // retry until we get a reasonable time of day
        eventHours = random.nextInt(4) + 1;
      } while ((currentHour + eventHours) > endHour);

      events.add(FlightBooking(
        'EVENT-${random.nextInt(10000000)}',
        pilotNames[random.nextInt(pilotNames.length)],
        currentDate.add(Duration(hours: currentHour)),
        currentDate.add(Duration(hours: currentHour + eventHours)),
        random.nextBool() ? fakeNotes[random.nextInt(fakeNotes.length)] : null,
      ));
      currentHour += eventHours + random.nextInt(4);
      numDayEvents++;
    }

    currentDate = currentDate.add(const Duration(days: 1));
  }
  return events;
}

// FIXME copied from the main app, but it could be useful to steer stuff for testing (locale, theme, ...).
// Another way could be by accepting a few constructor parameters...
class MainNavigationApp extends StatelessWidget {
  const MainNavigationApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AppConfig>(
        builder: (context, appConfig, child) => PlatformApp(
          onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context)!.appName,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            SfGlobalLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          // TEST
          //locale: const Locale('it', ''),
          initialRoute: 'pilot-select',
          routes: <String, WidgetBuilder>{
            '/': (context) => app.MainNavigation.withServices(appConfig,
              bookFlightCalendarService: FakeCalendarService(generateFakeEvents(appConfig.pilotNames)),
            ),
            'pilot-select': (context) => const PilotSelectScreen(),
          },
          debugShowCheckedModeBanner: false,
          material: (_, __) => MaterialAppData(
            // TEST
            //themeMode: ThemeMode.dark,
            theme: ThemeData(
              brightness: Brightness.light,
              primarySwatch: Colors.deepOrange,
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              primarySwatch: Colors.deepOrange,
            ),
          ),
          cupertino: (_, __) => CupertinoAppData(
            // TEST
            //theme: const CupertinoThemeData(brightness: Brightness.dark),
            // TODO
          ),
        ));
  }

}

class FakeAppConfig extends AppConfig {

  @override
  Future<void> init() async {
    prefs = FakeSharedPreferences({
      'currentAircraft': 'a1234',
      //'pilotName': 'Anna',
    });

    //final dataFile = File('test_driver/screenshots_data.zip');
    final reader = AircraftDataReader.fromBytes(
      //dataBytes: dataFile.readAsBytesSync(),
      dataBytes: kScreenshotsData,
      dataFilename: 'a1234.zip',
      url: 'http://localhost/a1234.zip',
    );
    await reader.open();

    currentAircraft = reader.toAircraftData();
  }

}

class FakeSharedPreferences implements SharedPreferences {

  FakeSharedPreferences(this.values);

  Map<String, Object?> values;

  @override
  Future<bool> clear() {
    throw UnimplementedError();
  }

  @override
  Future<bool> commit() {
    throw UnimplementedError();
  }

  @override
  bool containsKey(String key) {
    return values.containsKey(key);
  }

  @override
  Object? get(String key) {
    return values[key];
  }

  @override
  bool? getBool(String key) {
    return values[key] as bool?;
  }

  @override
  double? getDouble(String key) {
    return values[key] as double?;
  }

  @override
  int? getInt(String key) {
    return values[key] as int?;
  }

  @override
  Set<String> getKeys() {
    return Set.of(values.keys);
  }

  @override
  String? getString(String key) {
    return values[key]?.toString();
  }

  @override
  List<String>? getStringList(String key) {
    // TODO: implement getStringList
    throw UnimplementedError();
  }

  @override
  Future<void> reload() {
    throw UnimplementedError();
  }

  @override
  Future<bool> remove(String key) {
    throw UnimplementedError();
  }

  @override
  Future<bool> setBool(String key, bool value) {
    _setValue(key, value);
    return Future.value(true);
  }

  @override
  Future<bool> setDouble(String key, double value) {
    _setValue(key, value);
    return Future.value(true);
  }

  @override
  Future<bool> setInt(String key, int value) {
    _setValue(key, value);
    return Future.value(true);
  }

  @override
  Future<bool> setString(String key, String value) {
    _setValue(key, value);
    return Future.value(true);
  }

  void _setValue(String key, Object? value) {
    values[key] = value;
  }

  @override
  Future<bool> setStringList(String key, List<String> value) {
    // TODO: implement setStringList
    throw UnimplementedError();
  }

}

class FakeCalendarService implements BookFlightCalendarService {

  final Iterable<FlightBooking> events;

  const FakeCalendarService(this.events);

  @override
  Future<bool> bookingConflicts(Object calendarId, FlightBooking event) {
    // should be never called for making screenshots
    throw UnimplementedError();
  }

  @override
  Future<FlightBooking> createBooking(Object calendarId, FlightBooking event) {
    // should be never called for making screenshots
    throw UnimplementedError();
  }

  @override
  Future<DeletedFlightBooking> deleteBooking(Object calendarId, FlightBooking event) {
    // should be never called for making screenshots
    throw UnimplementedError();
  }

  @override
  Future<Iterable<FlightBooking>> search(Object calendarId, DateTime timeMin, DateTime timeMax) {
    return Future.value(events.where((element) =>
      (element.from.isAfter(timeMin) || element.from == timeMin) && (element.to.isBefore(timeMax) || element.to == timeMax)
    ));
  }

  @override
  Future<Object> updateBooking(Object calendarId, FlightBooking event) {
    // should be never called for making screenshots
    throw UnimplementedError();
  }

}
