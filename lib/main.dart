import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl_standalone.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'helpers/config.dart';
import 'helpers/utils.dart';
import 'screens/app.dart';

Future<void> main() async {
  Logger.root.level = kReleaseMode ? Level.INFO : Level.ALL;
  Logger.root.onRecord.listen((record) {
    if (kReleaseMode) {
      debugPrint(
          '${record.time} ${record.level.name} ${record.loggerName} - ${record.message}');
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
            create: (context) => DownloadProvider(() => HttpClient())),
      ],
      child: const MyApp(),
    ),
  );
}
