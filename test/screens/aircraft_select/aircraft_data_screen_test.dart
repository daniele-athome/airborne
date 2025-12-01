import 'package:airborne/generated/intl/app_localizations.dart';
import 'package:airborne/helpers/config.dart';
import 'package:airborne/helpers/utils.dart';
import 'package:airborne/screens/aircraft_select/aircraft_data_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../generate_mocks.mocks.dart';

void main() {
  Widget createSkeletonApp() => MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    locale: const Locale('en'),
    home: MultiProvider(
      providers: [
        _provideAppConfigForSampleAircraft(),
        _provideFakeDownloadProvider(),
      ],
      child: const SetAircraftDataScreen(),
    ),
  );

  group('Single aircraft data screen tests', () {
    testWidgets('An invalid URI in address field should not validate', (
      tester,
    ) async {
      await tester.pumpWidget(createSkeletonApp());
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is PlatformTextFormField &&
              widget.keyboardType == TextInputType.url,
        ),
        "NOT_VALID_URI",
      );
      await tester.pump();
      expect(tester.state<FormState>(find.byType(Form)).validate(), false);
    });

    testWidgets('A valid URI in address field should validate', (tester) async {
      await tester.pumpWidget(createSkeletonApp());
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is PlatformTextFormField &&
              widget.keyboardType == TextInputType.url,
        ),
        'http://localhost/a1234.zip',
      );
      await tester.pump();
      expect(tester.state<FormState>(find.byType(Form)).validate(), true);
    });
  });
}

ChangeNotifierProvider<AppConfig> _provideAppConfigForSampleAircraft() {
  final appConfig = MockAppConfig();
  // TODO stub some stuff
  return ChangeNotifierProvider<AppConfig>.value(value: appConfig);
}

ChangeNotifierProvider<DownloadProvider> _provideFakeDownloadProvider() {
  final client = MockHttpClient();
  return ChangeNotifierProvider<DownloadProvider>(
    create: (context) => DownloadProvider(() => client),
  );
}
