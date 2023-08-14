import 'package:airborne/helpers/config.dart';
import 'package:airborne/models/flight_log_models.dart';
import 'package:airborne/screens/flight_log/flight_log_modal.dart';
import 'package:airborne/services/flight_log_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'flight_log_modal_test.mocks.dart';

@GenerateMocks([AppConfig, FlightLogBookService])
void main() {
  Widget createSkeletonApp(FlightLogItem model) => MaterialApp(
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
            _provideFlightLogBookService(),
          ],
          child: FlightLogModal(model),
        ),
      );

  group('Register a new flight in log book', () {
    testWidgets('Fuel price validation', (tester) async {
      FlightLogItem item = FlightLogItem(
        null,
        DateTime.now(),
        'Sara',
        'Fly@localhost',
        'Fly@localhost',
        1238,
        1238,
        null,
        null,
        null,
      );
      await tester.pumpWidget(createSkeletonApp(item));

      await tester.enterText(
          find.byKey(const Key("flight_log_modal_form_fuel_price")), "42");
      await tester.pump();
      expect(tester.state<FormState>(find.byType(Form)).validate(), true);

      await tester.enterText(
          find.byKey(const Key("flight_log_modal_form_fuel_price")), "ABC");
      await tester.pump();
      expect(tester.state<FormState>(find.byType(Form)).validate(), false);

      await tester.enterText(
          find.byKey(const Key("flight_log_modal_form_fuel_price")), "43.2");
      await tester.pump();
      expect(tester.state<FormState>(find.byType(Form)).validate(), true);

      // FIXME this should fail on the locale of the test
      await tester.enterText(
          find.byKey(const Key("flight_log_modal_form_fuel_price")), "43,2");
      await tester.pump();
      expect(tester.state<FormState>(find.byType(Form)).validate(), true);
    });

    testWidgets('Fuel amount validation', (tester) async {
      // TODO
    });

    testWidgets('Fuel amount mandatory when fuel cost is greater than zero',
        (tester) async {
      // TODO
    });

    testWidgets('Fuel cost mandatory when fuel amount is greater than zero',
        (tester) async {
      // TODO
    });
  });
}

ChangeNotifierProvider<AppConfig> _provideAppConfigForSampleAircraft() {
  final appConfig = MockAppConfig();
  when(appConfig.getPilotAvatar(any))
      .thenReturn(const AssetImage('assets/images/nopilot_avatar.png'));
  when(appConfig.fuelPriceCurrency).thenReturn('€');
  // TODO stub some stuff
  return ChangeNotifierProvider<AppConfig>.value(
    value: appConfig,
  );
}

Provider<FlightLogBookService> _provideFlightLogBookService() {
  final service = MockFlightLogBookService();
  // TODO stub some stuff
  return Provider.value(value: service);
}
