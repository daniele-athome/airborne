import 'dart:developer' as developer;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
//import 'package:intl/intl.dart';
import 'package:intl/intl_standalone.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_localizations/syncfusion_localizations.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'helpers/config.dart';
import 'helpers/googleapis.dart';
import 'screens/about/about_screen.dart';
import 'screens/aircraft_select/aircraft_data_screen.dart';
import 'screens/book_flight/book_flight_screen.dart';
import 'screens/flight_log/flight_log_screen.dart';
import 'screens/pilot_select/pilot_select_screen.dart';
import 'services/book_flight_services.dart';
import 'services/flight_log_services.dart';

final Logger _log = Logger("main");

Future<void> main() async {
  Logger.root.level = kReleaseMode ? Level.INFO : Level.ALL;
  Logger.root.onRecord.listen((record) {
    if (kReleaseMode) {
      debugPrint('${record.time} ${record.level.name} ${record.loggerName} - ${record.message}');
      if (record.error != null) {
        debugPrint(record.error.toString());
      }
      if (record.stackTrace != null) {
        debugPrint(record.stackTrace.toString());
      }
    }
    else {
      developer.log(
        record.message,
        time: record.time,
        sequenceNumber: record.sequenceNumber,
        level: record.level.value,
        name: record.loggerName,
        zone: record.zone,
        error: record.error,
        stackTrace: record.stackTrace,
      );
    }
  });

  await findSystemLocale();
  // TODO do we need this?
  WidgetsFlutterBinding.ensureInitialized();
  // initialize timezone data
  tz_data.initializeTimeZones();

  // TEST
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  //Intl.systemLocale = 'it_IT';

  // we need configuration to be loaded so we block here
  // it's just assets reading anyway so it won't take long
  // FIXME this will also load the current aircraft, so it's not so fast afterall :P
  final appConfig = AppConfig();
  await appConfig.init();
  runApp(
    Provider.value(
      value: appConfig,
      builder: (_, __) => const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  String _getInitialRoute(AppConfig appConfig) {
    if (appConfig.aircrafts.isEmpty && appConfig.currentAircraft == null) {
      return 'aircraft-data';
    }
    else {
      return appConfig.pilotName != null ? '/' : 'pilot-select';
    }
  }

  @override
  Widget build(BuildContext context) {
    _log.finest('MAIN-BUILD');
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
        initialRoute: _getInitialRoute(appConfig),
        routes: <String, WidgetBuilder>{
          '/': (context) => MainNavigation(appConfig),
          'pilot-select': (context) => const PilotSelectScreen(),
          'aircraft-data': (context) => const SetAircraftDataScreen(),
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

class MainNavigation extends StatefulWidget {
  final AppConfig appConfig;

  final BookFlightCalendarService? bookFlightCalendarService;
  final FlightLogBookService? flightLogBookService;
  // TODO other services one day...

  const MainNavigation(this.appConfig, {Key? key})
      : bookFlightCalendarService = null,
        flightLogBookService = null,
        super(key: key);

  /// Mainly for integration testing.
  @visibleForTesting
  const MainNavigation.withServices(this.appConfig, {
    Key? key,
    this.bookFlightCalendarService,
    this.flightLogBookService,
  }) : super(key: key);

  @override
  _MainNavigationState createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late PlatformTabController _tabController;
  late BookFlightCalendarService? _bookFlightCalendarService;
  late FlightLogBookService? _flightLogBookService;

  @override
  void initState() {
    _tabController = PlatformTabController();
    final account = GoogleServiceAccountService(
        json: widget.appConfig.googleServiceAccountJson
    );
    _bookFlightCalendarService = widget.bookFlightCalendarService ??
      (widget.appConfig.hasFeature('book_flight') ? BookFlightCalendarService(account, widget.appConfig.googleCalendarId) : null);
    _flightLogBookService = widget.flightLogBookService ??
      (widget.appConfig.hasFeature('flight_log') ? FlightLogBookService(account, widget.appConfig.flightlogBackendInfo) : null);
    super.initState();
  }

  Widget _buildTab(BuildContext context, int index) {
    // FIXME find a more efficient way to do this
    return [
      if (widget.appConfig.hasFeature('book_flight')) () => Provider.value(
        value: _bookFlightCalendarService,
        child: const BookFlightScreen(),
      ),
      if (widget.appConfig.hasFeature('flight_log')) () => Provider.value(
        value: _flightLogBookService,
        child: const FlightLogScreen(),
      ),
      () => const AboutScreen(),
    ][index]();
  }

  @override
  Widget build(BuildContext context) {
    return PlatformTabScaffold(
      iosContentBottomPadding: true,
      // appBar is owned by screen
      bodyBuilder: (context, index) => _buildTab(context, index),
      tabController: _tabController,
      items: [
        if (widget.appConfig.hasFeature('book_flight')) BottomNavigationBarItem(
            icon: Icon(isCupertino(context)? CupertinoIcons.calendar : Icons.calendar_today_rounded),
            label: AppLocalizations.of(context)!.mainNav_bookFlight,
            tooltip: '',
        ),
        if (widget.appConfig.hasFeature('flight_log')) BottomNavigationBarItem(
            icon: Icon(isCupertino(context)? CupertinoIcons.book_solid : Icons.menu_book_sharp),
            label: AppLocalizations.of(context)!.mainNav_logBook,
            tooltip: '',
        ),
        BottomNavigationBarItem(
            icon: Icon(PlatformIcons(context).info),
            label: AppLocalizations.of(context)!.mainNav_about,
            tooltip: '',
        ),
      ],
      material: (_, __) => MaterialTabScaffoldData(
        // TODO
      ),
      cupertino: (_, __) => CupertinoTabScaffoldData(
        // TODO
      ),
    );
  }
}
