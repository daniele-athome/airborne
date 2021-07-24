import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:intl/intl.dart';
import 'package:intl/intl_standalone.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_localizations/syncfusion_localizations.dart';

import 'helpers/config.dart';
import 'helpers/googleapis.dart';
import 'screens/book_flight/book_flight_screen.dart';
import 'screens/flight_log/flight_log_screen.dart';
import 'screens/pilot_select/pilot_select_screen.dart';

Future<void> main() async {
  await findSystemLocale();
  // TODO do we need this?
  WidgetsFlutterBinding.ensureInitialized();

  // TEST
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  Intl.systemLocale = 'it_IT';

  // we need configuration to be loaded so we block here
  // it's just assets reading anyway so it won't take long
  final appConfig = AppConfig();
  await appConfig.init();
  runApp(
    Provider.value(
      value: appConfig,
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppConfig>(
        builder: (context, appConfig, child) => PlatformApp(
              onGenerateTitle: (BuildContext context) =>
                  AppLocalizations.of(context)!.appName,
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                SfGlobalLocalizations.delegate,
              ],
              supportedLocales: [
                const Locale('en', ''),
                const Locale('it', ''),
              ],
              // TEST
              locale: const Locale('it', ''),
              initialRoute:
                  appConfig.pilotName != null ? '/' : 'pilot-select',
              routes: <String, WidgetBuilder>{
                '/': (context) => MainNavigation(appConfig),
                'pilot-select': (context) => PilotSelectScreen(),
              },
              debugShowCheckedModeBanner: false,
              material: (_, __) => MaterialAppData(
                theme: ThemeData(
                  primarySwatch: Colors.deepOrange,
                ),
              ),
              cupertino: (_, __) => CupertinoAppData(
                // TODO
              ),
            ));
  }
}

class MainNavigation extends StatefulWidget {
  final AppConfig appConfig;

  MainNavigation(this.appConfig);

  @override
  _MainNavigationState createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late PlatformTabController _tabController;
  late GoogleServiceAccountService _googleServiceAccount;

  @override
  void initState() {
    _tabController = PlatformTabController(
      initialIndex: 0,
    );
    _googleServiceAccount = GoogleServiceAccountService(
        json: widget.appConfig.googleServiceAccountJson
    );
    super.initState();
  }

  Widget _buildTab(BuildContext context, int index) {
    switch (index) {
      case 0:
        return Provider.value(
          value: _googleServiceAccount,
          child: BookFlightScreen(),
        );
      case 1:
        return FlightLogScreen();
      // TODO info
      default:
        throw UnsupportedError('Unsupported tab');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlatformTabScaffold(
      iosContentBottomPadding: true,
      // appBar is owned by screen
      bodyBuilder: (context, index) => _buildTab(context, index),
      tabController: _tabController,
      items: [
        BottomNavigationBarItem(
            icon: Icon(isCupertino(context)? CupertinoIcons.calendar : Icons.calendar_today_rounded),
            label: AppLocalizations.of(context)!.mainNav_bookFlight,
            tooltip: '',
        ),
        BottomNavigationBarItem(
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
