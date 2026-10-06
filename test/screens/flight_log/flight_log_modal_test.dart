import 'dart:io';

import 'package:airborne/generated/intl/app_localizations.dart';
import 'package:airborne/helpers/config.dart';
import 'package:airborne/models/flight_log_models.dart';
import 'package:airborne/screens/flight_log/flight_log_modal.dart';
import 'package:airborne/services/flight_log_services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../../generate_mocks.mocks.dart';
import '../../golden_config.dart';

void main() async {
  const locale = Locale('en');
  final lang = await AppLocalizations.delegate.load(locale);

  Widget createSkeletonApp(
    FlightLogItem model, {
    MockFlightLogBookService? service,
  }) => MultiProvider(
    providers: [
      _provideAppConfigForSampleAircraft(),
      _provideFlightLogBookService(service),
    ],
    child: MaterialApp(
      // ignore: deprecated_member_use
      builder: (ctx, child) => MaterialUiCompatibilityBridge(child: child!),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      locale: locale,
      home: RepaintBoundary(
        key: const Key('golden_box'),
        child: FlightLogModal(model),
      ),
    ),
  );

  group('Flight log editor appearance', () {
    testWidgets('Launch appearance', (tester) async {
      await setupGolden(tester);

      FlightLogItem item = FlightLogItem(
        null,
        DateTime.parse('2023-10-27T10:00:00Z'),
        'Sara',
        'Fly@localhost',
        'Fly@localhost',
        1238,
        1240.5,
        null,
        null,
        null,
      );
      await tester.pumpWidget(createSkeletonApp(item));
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const Key('golden_box')),
        matchesGoldenFile('goldens/flight_log_modal_launch.png'),
        skip: !Platform.isLinux,
      );
    });
  });

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
        find.byKey(const Key("input_flightLogModal_fuelPrice")),
        "42",
      );
      await tester.pump();
      expect(tester.state<FormState>(find.byType(Form)).validate(), true);

      // letters never make it into the field in the first place
      await tester.enterText(
        find.byKey(const Key("input_flightLogModal_fuelPrice")),
        "ABC",
      );
      await tester.pump();
      expect(_textOf(tester, const Key("input_flightLogModal_fuelPrice")), '');
      expect(tester.state<FormState>(find.byType(Form)).validate(), true);

      await tester.enterText(
        find.byKey(const Key("input_flightLogModal_fuelPrice")),
        "43.2",
      );
      await tester.pump();
      expect(tester.state<FormState>(find.byType(Form)).validate(), true);

      await tester.enterText(
        find.byKey(const Key("input_flightLogModal_fuelPrice")),
        "43.28293",
      );
      await tester.pump();
      expect(tester.state<FormState>(find.byType(Form)).validate(), true);

      await tester.enterText(
        find.byKey(const Key("input_flightLogModal_fuelPrice")),
        "43.28",
      );
      await tester.pump();
      expect(tester.state<FormState>(find.byType(Form)).validate(), true);

      // the separator of another locale is taken for the decimal one
      await tester.enterText(
        find.byKey(const Key("input_flightLogModal_fuelPrice")),
        "43,2",
      );
      await tester.pump();
      expect(
        _textOf(tester, const Key("input_flightLogModal_fuelPrice")),
        '43.2',
      );
      expect(tester.state<FormState>(find.byType(Form)).validate(), true);
    });

    testWidgets('Fuel amount validation', (tester) async {
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
        find.byKey(const Key("input_flightLogModal_fuel")),
        "42",
      );
      await tester.pump();
      expect(tester.state<FormState>(find.byType(Form)).validate(), true);

      // letters never make it into the field in the first place
      await tester.enterText(
        find.byKey(const Key("input_flightLogModal_fuel")),
        "ABC",
      );
      await tester.pump();
      expect(_textOf(tester, const Key("input_flightLogModal_fuel")), '');
      expect(tester.state<FormState>(find.byType(Form)).validate(), true);

      await tester.enterText(
        find.byKey(const Key("input_flightLogModal_fuel")),
        "43.2",
      );
      await tester.pump();
      expect(tester.state<FormState>(find.byType(Form)).validate(), true);

      await tester.enterText(
        find.byKey(const Key("input_flightLogModal_fuel")),
        "43.28",
      );
      await tester.pump();
      expect(tester.state<FormState>(find.byType(Form)).validate(), true);

      await tester.enterText(
        find.byKey(const Key("input_flightLogModal_fuel")),
        "43.28",
      );
      await tester.pump();
      expect(tester.state<FormState>(find.byType(Form)).validate(), true);

      await tester.enterText(
        find.byKey(const Key("input_flightLogModal_fuel")),
        "43.2802",
      );
      await tester.pump();
      expect(tester.state<FormState>(find.byType(Form)).validate(), true);

      // the separator of another locale is taken for the decimal one
      await tester.enterText(
        find.byKey(const Key("input_flightLogModal_fuel")),
        "43,2",
      );
      await tester.pump();
      expect(_textOf(tester, const Key("input_flightLogModal_fuel")), '43.2');
      expect(tester.state<FormState>(find.byType(Form)).validate(), true);
    });

    testWidgets('Fuel amount mandatory when fuel cost is greater than zero', (
      tester,
    ) async {
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
        find.byKey(const Key("input_flightLogModal_fuelPrice")),
        "102.38",
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('button_flightLogModal_save')));
      await tester.pump();
      expect(find.byType(PlatformAlertDialog), findsOneWidget);
      expect(
        find.text(lang.flightLogModal_error_invalid_fuel_empty),
        findsOneWidget,
      );
    });

    testWidgets('Fuel cost mandatory when fuel amount is greater than zero', (
      tester,
    ) async {
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
        find.byKey(const Key("input_flightLogModal_fuel")),
        "102.38",
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('button_flightLogModal_save')));
      await tester.pump();
      expect(find.byType(PlatformAlertDialog), findsOneWidget);
      expect(
        find.text(lang.flightLogModal_error_invalid_fuelCost_empty),
        findsOneWidget,
      );
    });
  });

  group('Fuel numbers are read the same in every locale', () {
    const fuelKey = Key("input_flightLogModal_fuel");
    const fuelPriceKey = Key("input_flightLogModal_fuelPrice");

    FlightLogItem emptyItem() => FlightLogItem(
      null,
      DateTime.now(),
      'Sara',
      'Fly@localhost',
      'Fly@localhost',
      1238,
      1240,
      null,
      null,
      null,
    );

    /// Runs [body] with the number locale of the app set to [locale].
    void withNumberLocale(String locale) {
      final previous = Intl.defaultLocale;
      Intl.defaultLocale = locale;
      addTearDown(() => Intl.defaultLocale = previous);
    }

    testWidgets('a dot typed in a comma locale is a decimal separator', (
      tester,
    ) async {
      withNumberLocale('it');
      await tester.pumpWidget(createSkeletonApp(emptyItem()));

      await tester.enterText(find.byKey(fuelKey), "42.71");
      await tester.enterText(find.byKey(fuelPriceKey), "106.78");
      await tester.pump();

      // the field holds what an italian would have typed
      expect(_textOf(tester, fuelKey), '42,71');
      expect(_textOf(tester, fuelPriceKey), '106,78');
      expect(tester.state<FormState>(find.byType(Form)).validate(), true);
    });

    testWidgets('a comma typed in a dot locale is a decimal separator', (
      tester,
    ) async {
      withNumberLocale('en_US');
      await tester.pumpWidget(createSkeletonApp(emptyItem()));

      await tester.enterText(find.byKey(fuelKey), "42,71");
      await tester.enterText(find.byKey(fuelPriceKey), "106,78");
      await tester.pump();

      expect(_textOf(tester, fuelKey), '42.71');
      expect(_textOf(tester, fuelPriceKey), '106.78');
      expect(tester.state<FormState>(find.byType(Form)).validate(), true);
    });

    testWidgets('the saved flight carries the number that was typed', (
      tester,
    ) async {
      withNumberLocale('it');
      final service = MockFlightLogBookService();
      final saved = <FlightLogItem>[];
      when(
        service.appendItem(any, requestId: anyNamed('requestId')),
      ).thenAnswer((invocation) async {
        final item = invocation.positionalArguments.first as FlightLogItem;
        saved.add(item);
        return item;
      });

      await tester.pumpWidget(createSkeletonApp(emptyItem(), service: service));

      // a refuel of 42.71 litres for 106.78 euro, typed on a dot keyboard
      await tester.enterText(find.byKey(fuelKey), "42.71");
      await tester.enterText(find.byKey(fuelPriceKey), "106.78");
      await tester.pump();
      await tester.tap(find.byKey(const Key('button_flightLogModal_save')));
      await tester.pumpAndSettle();

      expect(saved, hasLength(1));
      // rounded to the decimals the log book keeps, not read as 4271
      expect(saved.single.fuel, 42.7);
      expect(saved.single.fuelPrice, 2.5);
    });

    testWidgets('the fuel of an existing flight shows in the locale', (
      tester,
    ) async {
      withNumberLocale('it');
      final item = FlightLogItem(
        'id',
        DateTime.now(),
        'Sara',
        'Fly@localhost',
        'Fly@localhost',
        1238,
        1240,
        42.7,
        2.5,
        null,
      );
      await tester.pumpWidget(createSkeletonApp(item));

      expect(_textOf(tester, fuelKey), '42,7');
      // the cost field holds the total, i.e. amount by price
      expect(_textOf(tester, fuelPriceKey), '106,75');
    });
  });
}

/// The text the field marked with [key] holds.
String _textOf(WidgetTester tester, Key key) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byKey(key),
        matching: find.byType(EditableText),
        matchRoot: true,
      ),
    )
    .controller
    .text;

ChangeNotifierProvider<AppConfig> _provideAppConfigForSampleAircraft() {
  final appConfig = MockAppConfig();
  when(
    appConfig.getPilotAvatar(any),
  ).thenReturn(const AssetImage('assets/images/nopilot_avatar.png'));
  when(appConfig.fuelPriceCurrency).thenReturn('€');
  when(appConfig.pilotName).thenReturn('Sara');
  when(appConfig.pilotNames).thenReturn(['Sara', 'Anna', 'John', 'Peter']);
  when(appConfig.hourmeterMultiplier).thenReturn(60);
  when(appConfig.admin).thenReturn(true);

  // TODO stub some stuff
  return ChangeNotifierProvider<AppConfig>.value(value: appConfig);
}

Provider<FlightLogBookService> _provideFlightLogBookService([
  MockFlightLogBookService? service,
]) {
  // TODO stub some stuff
  return Provider.value(value: service ?? MockFlightLogBookService());
}
