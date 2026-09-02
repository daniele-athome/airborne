import 'package:airborne/helpers/list_tiles.dart';
import 'package:airborne/helpers/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../fixtures/app.dart';

void main() {
  late DateFormat dateFormat;
  late DateFormat timeFormat;

  setUpAll(() async {
    // the widgets build their formatters once the delegates have loaded, tests
    // building the same ones up front have to ask for the data themselves
    await initializeDateFormatting('en');
    dateFormat = DateFormat.yMEd('en');
    timeFormat = DateFormat(kAviationTimeFormat, 'en');
  });

  /// Opens a picker, chooses [day] of the month on show, and confirms.
  Future<void> pickDay(WidgetTester tester, Finder tile, String day) async {
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.text(day));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  group('DateListTile', () {
    Future<DateTimePickerController> pumpTile(
      WidgetTester tester, {
      DateTime? initialValue,
      bool showIcon = true,
      TextStyle? textStyle,
      void Function(DateTime selected)? onDateSelected,
    }) async {
      final controller = DateTimePickerController(initialValue);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        createTestApp(
          home: Material(
            child: DateListTile(
              controller: controller,
              showIcon: showIcon,
              textStyle: textStyle,
              onDateSelected: onDateSelected,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('shows the date the controller holds', (tester) async {
      final value = DateTime(2020, 3, 15);
      await pumpTile(tester, initialValue: value);
      expect(find.text(dateFormat.format(value)), findsOneWidget);
    });

    testWidgets('shows nothing without a date', (tester) async {
      await pumpTile(tester);
      expect(find.text(''), findsWidgets);
      expect(find.byType(ListTile), findsOneWidget);
    });

    testWidgets('can hide the leading icon', (tester) async {
      await pumpTile(tester, initialValue: DateTime(2020, 3, 15));
      expect(find.byIcon(Icons.access_time), findsOneWidget);

      await pumpTile(
        tester,
        initialValue: DateTime(2020, 3, 15),
        showIcon: false,
      );
      expect(find.byIcon(Icons.access_time), findsNothing);
    });

    testWidgets('applies the given text style', (tester) async {
      final value = DateTime(2020, 3, 15);
      await pumpTile(
        tester,
        initialValue: value,
        textStyle: const TextStyle(fontSize: 42),
      );

      final text = tester.widget<Text>(find.text(dateFormat.format(value)));
      expect(text.style?.fontSize, 42);
    });

    testWidgets('records the date that was picked', (tester) async {
      final picked = <DateTime>[];
      final controller = await pumpTile(
        tester,
        initialValue: DateTime(2020, 3, 15),
        onDateSelected: picked.add,
      );

      await pickDay(tester, find.byType(ListTile), '20');

      expect(controller.value, DateTime(2020, 3, 20));
      expect(picked, [DateTime(2020, 3, 20)]);
    });

    testWidgets('leaves the date alone when the picker is dismissed', (
      tester,
    ) async {
      final picked = <DateTime>[];
      final controller = await pumpTile(
        tester,
        initialValue: DateTime(2020, 3, 15),
        onDateSelected: picked.add,
      );

      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(controller.value, DateTime(2020, 3, 15));
      expect(picked, isEmpty);
    });
  });

  group('DateTimeListTile', () {
    late List<(DateTime, DateTime)> dates;
    late List<(DateTime, DateTime)> times;

    Future<DateTimePickerController> pumpTile(
      WidgetTester tester, {
      DateTime? initialValue,
      bool showIcon = true,
    }) async {
      dates = [];
      times = [];
      final controller = DateTimePickerController(initialValue);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        createTestApp(
          home: Material(
            child: DateTimeListTile(
              controller: controller,
              showIcon: showIcon,
              onDateSelected: (selected, old) => dates.add((selected, old)),
              onTimeSelected: (selected, old) => times.add((selected, old)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    /// The tile carrying the date, on the left.
    Finder dateTile() => find.byType(ListTile).first;

    /// The tile carrying the time, on the right.
    Finder timeTile() => find.byType(ListTile).last;

    testWidgets('shows the date relatively and the time in aviation format', (
      tester,
    ) async {
      final value = DateTime(2020, 3, 15, 14, 30);
      await pumpTile(tester, initialValue: value);

      expect(find.text(dateFormat.format(value)), findsOneWidget);
      expect(find.text('14:30'), findsOneWidget);
    });

    testWidgets('names today instead of dating it', (tester) async {
      final today = DateTime.now();
      await pumpTile(tester, initialValue: today);

      expect(find.text('Today, ${dateFormat.format(today)}'), findsOneWidget);
      expect(find.text(timeFormat.format(today)), findsOneWidget);
    });

    testWidgets('shows nothing without a date', (tester) async {
      await pumpTile(tester);
      expect(find.text('14:30'), findsNothing);
      expect(find.byType(ListTile), findsNWidgets(2));
    });

    testWidgets('keeps the time when a new date is picked', (tester) async {
      final controller = await pumpTile(
        tester,
        initialValue: DateTime(2020, 3, 15, 14, 30),
      );

      await pickDay(tester, dateTile(), '20');

      expect(controller.value, DateTime(2020, 3, 20, 14, 30));
      expect(dates, [
        (DateTime(2020, 3, 20, 14, 30), DateTime(2020, 3, 15, 14, 30)),
      ]);
      expect(times, isEmpty);
    });

    testWidgets('keeps the date when a new time is picked', (tester) async {
      final controller = await pumpTile(
        tester,
        initialValue: DateTime(2020, 3, 15, 14, 30),
      );

      await tester.tap(timeTile());
      await tester.pumpAndSettle();
      // the dial is hard to aim at, the text fields are not
      await tester.tap(find.byTooltip('Switch to text input mode'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.first, '09');
      await tester.enterText(fields.last, '05');
      // the picker is in 12-hour mode for this locale
      await tester.tap(find.text('AM'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(controller.value, DateTime(2020, 3, 15, 9, 5));
      expect(times, [
        (DateTime(2020, 3, 15, 9, 5), DateTime(2020, 3, 15, 14, 30)),
      ]);
      expect(dates, isEmpty);
    });

    testWidgets('can hide the leading icon', (tester) async {
      await pumpTile(tester, initialValue: DateTime(2020, 3, 15, 14, 30));
      expect(find.byIcon(Icons.access_time), findsOneWidget);

      await pumpTile(
        tester,
        initialValue: DateTime(2020, 3, 15, 14, 30),
        showIcon: false,
      );
      expect(find.byIcon(Icons.access_time), findsNothing);
    });
  });
}
