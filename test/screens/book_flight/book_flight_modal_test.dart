import 'dart:io';

import 'package:airborne/generated/intl/app_localizations.dart';
import 'package:airborne/helpers/utils.dart';
import 'package:airborne/models/book_flight_models.dart';
import 'package:airborne/screens/book_flight/book_flight_modal.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart';

import '../../fixtures/app.dart';
import '../../fixtures/book_flight.dart';
import '../../golden_config.dart';

/// What the booking modal shows when it opens, on both design languages. The
/// modal is mounted on its own: nothing here presses a button.
///
/// What it does once a button is pressed is in
/// `book_flight_modal_flow_test.dart`.
void main() async {
  const locale = Locale('en');
  final lang = await AppLocalizations.delegate.load(locale);

  tz_data.initializeTimeZones();
  await initializeDateFormatting(locale.languageCode);

  final location = kHomeBase;
  final dateFormat = DateFormat.yMEd(locale.languageCode);
  final timeFormat = DateFormat(kAviationTimeFormat, locale.languageCode);

  final pastFrom = kSampleFrom;
  final pastTo = kSampleTo;

  /// Mounts the modal the way it is presented: a full screen dialog over the
  /// booking screen, which on material is where its close button comes from.
  /// The route below it is never anything but a backdrop.
  Future<void> pumpModal(
    WidgetTester tester,
    FlightBooking event, {
    TargetPlatform platform = TargetPlatform.android,
    bool golden = false,
  }) async {
    final modal = BookFlightModal(event);
    Route<void> modalRoute() {
      Widget builder(BuildContext context) => golden ? goldenBox(modal) : modal;
      return platform == TargetPlatform.iOS
          ? CupertinoPageRoute(builder: builder, fullscreenDialog: true)
          : MaterialPageRoute(builder: builder, fullscreenDialog: true);
    }

    await tester.pumpWidget(
      createTestApp(
        platform: platform,
        locale: locale,
        providers: bookFlightProviders(mockAppConfig(), mockCalendarService()),
        home: Navigator(
          onGenerateInitialRoutes: (_, _) => [
            PageRouteBuilder<void>(pageBuilder: (_, _, _) => const SizedBox()),
            modalRoute(),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The sunrise and sunset the modal is expected to show for [value].
  SunTimes sunTimes(TZDateTime value) =>
      getSunTimes(kLatitude, kLongitude, value, location);

  void expectSunTimes(Key key, SunTimes expected) {
    for (final time in [expected.sunrise, expected.sunset]) {
      expect(
        find.descendant(
          of: find.byKey(key),
          matching: find.text(timeFormat.format(time)),
        ),
        findsOneWidget,
      );
    }
  }

  /// Goldens are named after the design language, not the target platform.
  const goldenName = {
    TargetPlatform.android: 'material',
    TargetPlatform.iOS: 'cupertino',
  };

  group('Booking form appearance', () {
    testWidgets('a new booking has no delete button', (tester) async {
      for (final platform in kTestPlatforms) {
        await pumpModal(tester, sampleBooking(), platform: platform);

        expect(
          find.text(lang.bookFlightModal_title_create),
          findsOneWidget,
          reason: '$platform',
        );
        expect(
          find.text(lang.bookFlightModal_title_edit),
          findsNothing,
          reason: '$platform',
        );
        expect(
          find.byKey(const Key('button_bookFlightModal_delete')),
          findsNothing,
          reason: '$platform',
        );
        expect(
          find.byKey(const Key('button_bookFlightModal_save')),
          findsOneWidget,
          reason: '$platform',
        );
      }
    });

    testWidgets('an existing booking can be deleted', (tester) async {
      for (final platform in kTestPlatforms) {
        await pumpModal(
          tester,
          sampleBooking(id: 'event1'),
          platform: platform,
        );

        expect(
          find.text(lang.bookFlightModal_title_edit),
          findsOneWidget,
          reason: '$platform',
        );
        expect(
          find.byKey(const Key('button_bookFlightModal_delete')),
          findsOneWidget,
          reason: '$platform',
        );
      }
    });

    testWidgets('shows the pilot of the booking', (tester) async {
      for (final platform in kTestPlatforms) {
        await pumpModal(
          tester,
          sampleBooking(pilotName: kOtherPilot),
          platform: platform,
        );

        expect(find.text(kOtherPilot), findsOneWidget, reason: '$platform');
        expect(
          find.byKey(const Key('button_bookFlightModal_pilot')),
          findsOneWidget,
          reason: '$platform',
        );
        expect(find.byType(CircleAvatar), findsOneWidget, reason: '$platform');
      }
    });

    testWidgets('shows the notes of the booking', (tester) async {
      for (final platform in kTestPlatforms) {
        await pumpModal(
          tester,
          sampleBooking(notes: 'Trip to the seaside'),
          platform: platform,
        );

        expect(
          find.text('Trip to the seaside'),
          findsOneWidget,
          reason: '$platform',
        );
      }
    });

    testWidgets('hints at the notes when there are none', (tester) async {
      for (final platform in kTestPlatforms) {
        await pumpModal(tester, sampleBooking(), platform: platform);

        expect(
          find.text(lang.bookFlightModal_hint_notes),
          findsOneWidget,
          reason: '$platform',
        );
      }
    });

    testWidgets('shows the dates of the booking', (tester) async {
      // the cupertino date and time buttons come from a third party package,
      // the golden covers what they render
      await pumpModal(tester, sampleBooking());

      expect(find.text(dateFormat.format(pastFrom)), findsNWidgets(2));
      expect(find.text(timeFormat.format(pastFrom)), findsOneWidget);
      expect(find.text(timeFormat.format(pastTo)), findsOneWidget);
    });

    testWidgets('shows sunrise and sunset of both dates', (tester) async {
      final endOfYear = bookingDateTime(2023, 12, 27, 12, 30);
      for (final platform in kTestPlatforms) {
        await pumpModal(
          tester,
          sampleBooking(from: pastFrom, to: endOfYear),
          platform: platform,
        );

        expectSunTimes(
          const Key('text_bookFlightModal_startSunTimes'),
          sunTimes(pastFrom),
        );
        expectSunTimes(
          const Key('text_bookFlightModal_endSunTimes'),
          sunTimes(endOfYear),
        );
      }
    });

    testWidgets('golden: a new booking', (tester) async {
      for (final platform in kTestPlatforms) {
        await setupGolden(tester);
        await pumpModal(
          tester,
          sampleBooking(notes: 'Trip to the seaside'),
          platform: platform,
          golden: true,
        );

        await expectLater(
          find.byKey(kGoldenBoxKey),
          matchesGoldenFile(
            'goldens/book_flight_modal_new_${goldenName[platform]}.png',
          ),
          skip: !Platform.isLinux,
        );
      }
    });

    testWidgets('golden: an existing booking', (tester) async {
      for (final platform in kTestPlatforms) {
        await setupGolden(tester);
        await pumpModal(
          tester,
          sampleBooking(id: 'event1', notes: 'Trip to the seaside'),
          platform: platform,
          golden: true,
        );

        await expectLater(
          find.byKey(kGoldenBoxKey),
          matchesGoldenFile(
            'goldens/book_flight_modal_edit_${goldenName[platform]}.png',
          ),
          skip: !Platform.isLinux,
        );
      }
    });
  });
}
