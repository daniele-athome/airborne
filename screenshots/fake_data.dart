import 'dart:math';

import 'package:airborne/helpers/aircraft_data.dart';
import 'package:airborne/helpers/config.dart';
import 'package:airborne/helpers/googleapis.dart';
import 'package:airborne/models/activities_models.dart';
import 'package:airborne/models/book_flight_models.dart';
import 'package:airborne/models/flight_log_models.dart';
import 'package:airborne/screens/main/main_screen.dart' as main_screen;
import 'package:airborne/screens/pilot_select/pilot_select_screen.dart';
import 'package:airborne/services/activities_services.dart';
import 'package:airborne/services/book_flight_services.dart';
import 'package:airborne/services/flight_log_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_localizations/syncfusion_localizations.dart';
import 'package:timezone/timezone.dart';

import 'screenshots_data.dart';

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
    // 40% chance of having events on any given day (except for today)
    final numEventsPerDay = random.nextInt(4) + 1;
    final numEvents = !DateUtils.isSameDay(currentDate, now) ? (random.nextInt(100 ~/ 40) == 0 ? numEventsPerDay : 0) : numEventsPerDay;
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

/// Generates some random log book items.
List<FlightLogItem> generateFakeLogBookItems(List<String> pilotNames) {
  const fakePlaces = [
    'Fly Berlin',
    'Elba',
    'NYC',
    'LIRU',
    'London',
  ];
  final random = Random();
  double startHour = 2180;
  double lastDuration = 0.2;
  double endHour = startHour + lastDuration;
  return List<FlightLogItem>.generate(30, (index) {
    final hasFuel = random.nextBool();
    final item = FlightLogItem(
      index.toString(),
      DateTime.now().add(Duration(days: index)),
      pilotNames[random.nextInt(pilotNames.length)],
      fakePlaces[random.nextInt(fakePlaces.length)],
      fakePlaces[random.nextInt(fakePlaces.length)],
      startHour,
      endHour,
      hasFuel ? 20 : null,
      hasFuel ? 1 : null,
      null,
    );
    startHour = endHour;
    lastDuration = (random.nextDouble() * 100).toInt() / 100;
    endHour = startHour + lastDuration;
    return item;
  }, growable: false);
}

/// Generates some random activities.
List<ActivityEntry> generateFakeActivities(List<String> pilotNames) {
  // summary, type, description
  const allFakeEntries = {
    'en': [
      ['Landing gear damaged', ActivityType.critical, 'The landing gear was damaged during a hard landing. The crossbow needs to be replaced.'],
      ['New app version!', ActivityType.note, 'Version 3.0.4 was released in app stores!'],
      ['Battery cable damage', ActivityType.important, null],
      ['Washing needed!', ActivityType.minor, null],
      ['August 2022 hangar payment', ActivityType.important, null],
      ['Transponder not working properly', ActivityType.important, 'Some glitch there.'],
      ['Relevant NOTAM warning', ActivityType.notice, 'Beware of the dangerous zone above mount Everest.'],
    ],
    'it': [
      ['Carrello distrutto', ActivityType.critical, 'Distrutto durante l\'ultimo atterraggio. La balestra deve essere sostituita.'],
      ['Nuova versione app!', ActivityType.note, 'Versione 3.0.4 rilasciata negli app store!'],
      ['Cavo batteria danneggiato', ActivityType.important, null],
      ['Aereo da lavare!', ActivityType.minor, null],
      ['Pagamento hangar agosto 2022', ActivityType.important, null],
      ['Transponder non funziona', ActivityType.important, 'Qualche problema.'],
      ['NOTAM rilevante', ActivityType.notice, 'Attenzione alla zona pericolosa sopra il monte Everest.'],
    ],
  };
  final language = Intl.shortLocale(Intl.getCurrentLocale());
  final fakeEntries = List.of(allFakeEntries[language]!.reversed, growable: false);

  final random = Random();
  final now = DateTime.now();
  // matches with the one in the zip file
  final location = getLocation('Europe/Rome');
  final startDate = TZDateTime.from(DateTime(now.year, now.month, now.day), location).subtract(const Duration(days: 30));
  TZDateTime currentDate = startDate;

  return List<ActivityEntry>.generate(fakeEntries.length, (index) {
    currentDate = currentDate.add(const Duration(days: 1));
    final itemIndex = index % fakeEntries.length;
    final summary = fakeEntries[itemIndex][0] as String;
    final type = fakeEntries[itemIndex][1] as ActivityType;
    final description = fakeEntries[itemIndex][2] as String?;

    return ActivityEntry(
      id: index.toString(),
      type: type,
      creationDate: currentDate,
      author: pilotNames[random.nextInt(pilotNames.length)],
      summary: summary,
      description: description,
      // TODO proper random due date
      dueDate: random.nextBool() ? DateTime.now() : null,
      // status should be compatible with type
      status: type.task ? ActivityStatus.values[random.nextInt(ActivityStatus.values.length)] : null,
      alert: random.nextBool() ? random.nextBool() : null,
    );
  }, growable: false);
}

// FIXME copied from the main app, but it could be useful to steer stuff for testing (locale, theme, ...).
// Another way could be by accepting a few constructor parameters...
class MainNavigationApp extends StatelessWidget {
  MainNavigationApp({Key? key, this.initialRoute}) : super(key: key);

  final String? initialRoute;

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
          initialRoute: initialRoute ?? (appConfig.pilotName != null ? '/' : 'pilot-select'),
          routes: <String, WidgetBuilder>{
            '/': (context) => main_screen.MainNavigation.withServices(appConfig,
              bookFlightCalendarService: FakeCalendarService(generateFakeEvents(appConfig.pilotNames)),
              flightLogBookService: FakeLogBookService(generateFakeLogBookItems(appConfig.pilotNames)),
              activitiesService: FakeActivitiesService(generateFakeActivities(appConfig.pilotNames)),
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
  final String? initPilotName;

  FakeAppConfig() : initPilotName = null;
  FakeAppConfig.withPilotName(this.initPilotName);

  @override
  Future<void> init() async {
    prefs = FakeSharedPreferences({
      'currentAircraft': 'a1234',
      'pilotName': initPilotName,
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
  Future<bool> bookingConflicts(FlightBooking event) {
    // should be never called for making screenshots
    throw UnimplementedError();
  }

  @override
  Future<FlightBooking> createBooking(FlightBooking event) {
    // should be never called for making screenshots
    throw UnimplementedError();
  }

  @override
  Future<DeletedFlightBooking> deleteBooking(FlightBooking event) {
    // should be never called for making screenshots
    throw UnimplementedError();
  }

  @override
  Future<Iterable<FlightBooking>> search(DateTime timeMin, DateTime timeMax) {
    return Future.value(events.where((element) =>
    (element.from.isAfter(timeMin) || element.from == timeMin) && (element.to.isBefore(timeMax) || element.to == timeMax)
    ));
  }

  @override
  Future<FlightBooking> updateBooking(FlightBooking event) {
    // should be never called for making screenshots
    throw UnimplementedError();
  }

  @override
  set client(GoogleCalendarService client) {
    // should be never called for making screenshots
    throw UnimplementedError();
  }

}

class FakeLogBookService implements FlightLogBookService {

  final Iterable<FlightLogItem> items;
  bool _fetched = false;

  FakeLogBookService(this.items);

  @override
  Future<FlightLogItem> appendItem(FlightLogItem item) {
    throw UnimplementedError();
  }

  @override
  Future<DeletedFlightLogItem> deleteItem(FlightLogItem item) {
    throw UnimplementedError();
  }

  @override
  Future<Iterable<FlightLogItem>> fetchItems() {
    if (!_fetched) {
      _fetched = true;
      return Future.value(items);
    }
    else {
      return Future.value(List.empty());
    }
  }

  @override
  bool hasMoreData() {
    return !_fetched;
  }

  @override
  Future<void> reset() {
    _fetched = false;
    return Future.value();
  }

  @override
  Future<FlightLogItem> updateItem(FlightLogItem item) {
    throw UnimplementedError();
  }

  @override
  set client(GoogleSheetsService client) {
    throw UnimplementedError();
  }

  @override
  int get lastId => throw UnimplementedError();

  @override
  set lastId(int lastId) {
    throw UnimplementedError();
  }

}

class FakeActivitiesService implements ActivitiesService {

  final Iterable<ActivityEntry> items;
  bool _fetched = false;

  FakeActivitiesService(this.items);

  @override
  Future<Iterable<ActivityEntry>> fetchItems() {
    if (!_fetched) {
      _fetched = true;
      return Future.value(items);
    }
    else {
      return Future.value(List.empty());
    }
  }

  @override
  bool hasMoreData() {
    return !_fetched;
  }

  @override
  Future<void> reset() {
    _fetched = false;
    return Future.value();
  }

  @override
  set client(GoogleSheetsService client) {
    throw UnimplementedError();
  }

  @override
  int get lastId => throw UnimplementedError();

  @override
  set lastId(int lastId) {
    throw UnimplementedError();
  }

}
