import 'package:airborne/generated/intl/app_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// The platforms every widget test should cover: nearly all helpers branch on
/// [isCupertino].
const kTestPlatforms = [TargetPlatform.android, TargetPlatform.iOS];

/// Same delegates as `MyApp`, minus the syncfusion one which no helper needs.
const List<LocalizationsDelegate<dynamic>> kTestLocalizationsDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Wraps [home] in a localized [PlatformApp], rendered as Material or Cupertino
/// according to [platform].
Widget createTestApp({
  required Widget home,
  TargetPlatform platform = TargetPlatform.android,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  List<SingleChildWidget> providers = const [],
  List<NavigatorObserver> navigatorObservers = const [],
}) {
  return PlatformProvider(
    // PlatformProvider only reads initialPlatform in initState, so a test
    // pumping a second platform needs a fresh state to switch
    key: ValueKey(platform),
    initialPlatform: platform,
    builder: (context) {
      final Widget app = PlatformApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        navigatorObservers: navigatorObservers,
        debugShowCheckedModeBanner: false,
        home: home,
        material: (_, _) =>
            MaterialAppData(theme: ThemeData(brightness: brightness)),
        cupertino: (_, _) =>
            CupertinoAppData(theme: CupertinoThemeData(brightness: brightness)),
      );
      return providers.isEmpty
          ? app
          : MultiProvider(providers: providers, child: app);
    },
  );
}

/// Pumps a test app whose only job is to hand back a localized [BuildContext],
/// for testing functions that need one.
Future<BuildContext> pumpTestContext(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.android,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  List<SingleChildWidget> providers = const [],
}) async {
  late BuildContext captured;
  await tester.pumpWidget(
    createTestApp(
      platform: platform,
      locale: locale,
      brightness: brightness,
      providers: providers,
      home: Builder(
        builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  // MaterialApp animates theme changes, so a single frame would still expose
  // the previous theme when a test pumps more than one
  await tester.pumpAndSettle();
  return captured;
}
