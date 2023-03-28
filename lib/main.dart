import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'helpers/utils.dart';
import 'screens/aircraft_select/aircraft_data_screen.dart';
import 'screens/main/main_screen.dart';
import 'screens/pilot_select/pilot_select_screen.dart';

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
      // FIXME doesn't work in tests, use debugPrint (it should be overridden in tests)
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
  //debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  //Intl.systemLocale = 'it_IT';

  // we need configuration to be loaded so we block here
  // it's just assets reading anyway so it won't take long
  // FIXME this will also load the current aircraft, so it's not so fast afterall :P
  final appConfig = AppConfig();
  await appConfig.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppConfig>.value(
          value: appConfig
        ),
        ChangeNotifierProvider<DownloadProvider>(
          create: (context) => DownloadProvider(() => HttpClient())
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
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
          // there is probably a better way to avoid loading the routes...
          '/': (context) => appConfig.currentAircraft != null ?
            MainNavigation(appConfig) : const SizedBox.shrink(),
          'pilot-select': (context) => appConfig.currentAircraft != null ?
            const PilotSelectScreen() : const SizedBox.shrink(),
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
