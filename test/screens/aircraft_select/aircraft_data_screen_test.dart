
import 'package:airborne/helpers/config.dart';
import 'package:airborne/screens/aircraft_select/aircraft_data_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';

import 'aircraft_data_screen_test.mocks.dart';

@GenerateMocks([AppConfig])
void main() {
  Widget createSkeletonApp() => MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        locale: const Locale('en'),
        home: _provideAppConfigForSampleAircraft(const SetAircraftDataScreen())
    );

  group('Single aircraft data screen tests', () {
    testWidgets('An invalid URI in address field should not validate', (tester) async {
      await tester.pumpWidget(createSkeletonApp());
      await tester.enterText(
          find.byWidgetPredicate((widget) => widget is PlatformTextFormField &&
              widget.keyboardType == TextInputType.url), "NOT_VALID_URI");
      await tester.tap(
          find.byWidgetPredicate((widget) => widget is PlatformButton &&
              (widget.child! as Text).data == 'Install')
      );
      await tester.pumpAndSettle();
      expect(tester.state<FormState>(find.byType(Form)).validate(), false);
    });
  });
}

Provider<AppConfig> _provideAppConfigForSampleAircraft(Widget child) {
  final appConfig = MockAppConfig();
  // TODO stub some stuff
  return Provider.value(
    value: appConfig,
    builder: (context, __) => child,
  );
}
