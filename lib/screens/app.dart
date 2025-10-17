import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_localizations/syncfusion_localizations.dart';

import '../generated/intl/app_localizations.dart';
import '../helpers/config.dart';
import 'aircraft_select/aircraft_data_screen.dart';
import 'main/main_screen.dart';
import 'pilot_select/pilot_select_screen.dart';

final Logger _log = Logger("app");

class MyApp extends StatefulWidget {
  const MyApp({super.key});

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
    } else {
      return appConfig.pilotName != null ? '/' : 'pilot-select';
    }
  }

  @override
  Widget build(BuildContext context) {
    _log.finest('MAIN-BUILD');
    final AppConfig appConfig = Provider.of<AppConfig>(context, listen: false);
    return PlatformApp(
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
      // TEST locale: const Locale('it', ''),
      initialRoute: _getInitialRoute(appConfig),
      routes: <String, WidgetBuilder>{
        // there is probably a better way to avoid loading the routes...
        '/': (context) => Consumer<AppConfig>(
          builder: (context, appConfig, child) => MainNavigation(appConfig),
        ),
        'pilot-select': (context) => const PilotSelectScreen(),
        'aircraft-data': (context) => const SetAircraftDataScreen(),
      },
      debugShowCheckedModeBanner: false,
      material: (_, _) => MaterialAppData(
        // TEST themeMode: ThemeMode.dark,
        theme: ThemeData.light(useMaterial3: true).copyWith(
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(
            brightness: Brightness.light,
            seedColor: Colors.orange,
            primary: Colors.deepOrange,
            secondary: Colors.red,
            tertiary: Colors.lightGreen,
            dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
          ),
        ),
        darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            brightness: Brightness.dark,
            seedColor: Colors.orange,
            primary: Colors.deepOrange,
            secondary: Colors.red,
            tertiary: Colors.lightGreen,
            dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
          ),
        ),
      ),
      cupertino: (_, _) => CupertinoAppData(
        // TEST theme: const CupertinoThemeData(brightness: Brightness.dark),
        // TODO
      ),
    );
  }
}
