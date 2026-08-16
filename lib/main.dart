import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl_standalone.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'helpers/config.dart';
import 'helpers/googleapis.dart';
import 'helpers/utils.dart';
import 'screens/app.dart';
import 'services/activities_services.dart';
import 'services/book_flight_services.dart';
import 'services/flight_log_services.dart';
import 'services/script_client.dart';

final Logger _log = Logger("main");

Future<void> main() async {
  Logger.root.level = kReleaseMode ? Level.INFO : Level.ALL;
  Logger.root.onRecord.listen((record) {
    if (kReleaseMode) {
      debugPrint(
        '${record.time} ${record.level.name} ${record.loggerName} - ${record.message}',
      );
      if (record.error != null) {
        debugPrint(record.error.toString());
      }
      if (record.stackTrace != null) {
        debugPrint(record.stackTrace.toString());
      }
    } else {
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
        ChangeNotifierProvider<AppConfig>.value(value: appConfig),
        ChangeNotifierProvider<DownloadProvider>(
          create: (context) => DownloadProvider(() => HttpClient()),
        ),
        // account service: only bookings still use Google APIs directly
        ProxyProvider<AppConfig, GoogleServiceAccountService?>(
          update: (_, appConfig, _) {
            _log.finest('build account_service');
            return appConfig.hasFeature('book_flight')
                ? GoogleServiceAccountService(
                    json: appConfig.googleServiceAccountJson,
                  )
                : null;
          },
        ),
        // backend script client: the root of the sheet-backed services
        ProxyProvider<AppConfig, ScriptClient?>(
          update: (_, appConfig, _) {
            _log.finest('build script_client');
            return appConfig.currentAircraft != null &&
                    (appConfig.hasFeature('flight_log') ||
                        appConfig.hasFeature('activities'))
                ? ScriptClient(
                    url: appConfig.scriptUrl,
                    token: appConfig.scriptToken,
                  )
                : null;
          },
        ),
        ProxyProvider2<
          AppConfig,
          GoogleServiceAccountService?,
          BookFlightCalendarService?
        >(
          update: (_, appConfig, account, _) {
            _log.finest('build book_flight');
            return appConfig.hasFeature('book_flight') && account != null
                ? BookFlightCalendarService(account, appConfig.googleCalendarId)
                : null;
          },
        ),
        ProxyProvider2<AppConfig, ScriptClient?, FlightLogBookService?>(
          update: (_, appConfig, scriptClient, _) {
            _log.finest('build flight_log');
            return appConfig.hasFeature('flight_log') && scriptClient != null
                ? FlightLogBookService(scriptClient)
                : null;
          },
        ),
        ProxyProvider2<AppConfig, ScriptClient?, ActivitiesService?>(
          update: (_, appConfig, scriptClient, _) {
            _log.finest('build activities');
            return appConfig.hasFeature('activities') && scriptClient != null
                ? ActivitiesService(scriptClient)
                : null;
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}
