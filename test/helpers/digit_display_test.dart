import 'dart:io';

import 'package:airborne/helpers/digit_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/app.dart';
import '../golden_config.dart';

void main() {
  /// The digits currently on display, in order.
  List<SingleDigitText> digitsOf(WidgetTester tester) =>
      tester.widgetList<SingleDigitText>(find.byType(SingleDigitText)).toList();

  Future<void> pumpField(
    WidgetTester tester, {
    DigitDisplayController? controller,
    bool enabled = false,
    String? errorText,
  }) => tester.pumpWidget(
    createTestApp(
      home: Center(
        child: DigitDisplayTextField(
          controller: controller,
          enabled: enabled,
          errorText: errorText,
        ),
      ),
    ),
  );

  group('DigitDisplayController', () {
    test('keeps the number and the active digit apart', () {
      final controller = DigitDisplayController(12.5, 3);
      addTearDown(controller.dispose);

      expect(controller.number, 12.5);
      expect(controller.activeDigit, 3);

      controller.number = 99;
      expect(controller.number, 99);
      expect(controller.activeDigit, 3, reason: 'the active digit moved');

      controller.activeDigit = 0;
      expect(controller.activeDigit, 0);
      expect(controller.number, 99, reason: 'the number moved');
    });

    test('notifies on every change', () {
      final controller = DigitDisplayController(0);
      addTearDown(controller.dispose);

      var notified = 0;
      controller.addListener(() => notified++);

      controller.number = 1;
      controller.activeDigit = 2;
      expect(notified, 2);
    });

    test('starts with no active digit', () {
      final controller = DigitDisplayController(0);
      addTearDown(controller.dispose);
      expect(controller.activeDigit, isNull);
    });
  });

  group('DigitDisplayTextField', () {
    testWidgets('shows five integer digits and two decimals', (tester) async {
      final controller = DigitDisplayController(1234.5);
      addTearDown(controller.dispose);
      await pumpField(tester, controller: controller);

      final digits = digitsOf(tester);
      expect(digits, hasLength(kMaxDisplayIntegerDigits + 2));
      expect(digits.map((d) => d.digit), [0, 1, 2, 3, 4, 5, 0]);
      // only the last two are past the decimal point
      expect(digits.map((d) => d.decimal), [
        false,
        false,
        false,
        false,
        false,
        true,
        true,
      ]);
    });

    testWidgets('shows zero without a controller', (tester) async {
      await pumpField(tester);
      expect(digitsOf(tester).map((d) => d.digit), [0, 0, 0, 0, 0, 0, 0]);
    });

    testWidgets('rounds to the hundredth of an hour', (tester) async {
      final controller = DigitDisplayController(1.2345);
      addTearDown(controller.dispose);
      await pumpField(tester, controller: controller);

      expect(digitsOf(tester).map((d) => d.digit), [0, 0, 0, 0, 1, 2, 3]);
    });

    testWidgets('highlights the digit the controller points at', (
      tester,
    ) async {
      final controller = DigitDisplayController(1234.5, 2);
      addTearDown(controller.dispose);
      await pumpField(tester, controller: controller);

      expect(digitsOf(tester).map((d) => d.active), [
        false,
        false,
        true,
        false,
        false,
        false,
        false,
      ]);
    });

    testWidgets('refuses more than five integer digits', (tester) async {
      final controller = DigitDisplayController(100000);
      addTearDown(controller.dispose);
      await pumpField(tester, controller: controller);

      expect(tester.takeException(), isA<UnsupportedError>());
    });

    testWidgets('accepts the largest number it can show', (tester) async {
      final controller = DigitDisplayController(99999);
      addTearDown(controller.dispose);
      await pumpField(tester, controller: controller);

      expect(tester.takeException(), isNull);
      expect(digitsOf(tester).map((d) => d.digit), [9, 9, 9, 9, 9, 0, 0]);
    });

    testWidgets('ignores taps while disabled', (tester) async {
      final controller = DigitDisplayController(1234.5);
      addTearDown(controller.dispose);
      await pumpField(tester, controller: controller);

      expect(find.byType(GestureDetector), findsNothing);
      expect(controller.activeDigit, isNull);
    });

    testWidgets('moves the active digit on tap when enabled', (tester) async {
      final controller = DigitDisplayController(1234.5);
      addTearDown(controller.dispose);
      await pumpField(tester, controller: controller, enabled: true);

      // the third digit from the left
      await tester.tap(find.byType(SingleDigitText).at(2));
      await tester.pump();
      expect(controller.activeDigit, 2);
      expect(digitsOf(tester)[2].active, true);

      // and the first decimal
      await tester.tap(find.byType(SingleDigitText).at(5));
      await tester.pump();
      expect(controller.activeDigit, 5);
      expect(digitsOf(tester)[2].active, false);
    });

    testWidgets('shows an error underneath when given one', (tester) async {
      final controller = DigitDisplayController(1);
      addTearDown(controller.dispose);

      await pumpField(tester, controller: controller);
      expect(find.text('too much'), findsNothing);

      await pumpField(tester, controller: controller, errorText: 'too much');
      expect(find.text('too much'), findsOneWidget);
    });
  });

  group('DigitDisplayFormTextField', () {
    testWidgets('takes its initial value from the controller', (tester) async {
      final controller = DigitDisplayController(42.75);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        createTestApp(
          home: Center(
            child: Form(
              child: DigitDisplayFormTextField(controller: controller),
            ),
          ),
        ),
      );

      final field = tester.state<FormFieldState<num>>(
        find.byType(DigitDisplayFormTextField),
      );
      expect(field.value, 42.75);
      expect(digitsOf(tester).map((d) => d.digit), [0, 0, 0, 4, 2, 7, 5]);
    });

    testWidgets('reports the value on save', (tester) async {
      final controller = DigitDisplayController(7);
      addTearDown(controller.dispose);
      final formKey = GlobalKey<FormState>();
      num? saved;

      await tester.pumpWidget(
        createTestApp(
          home: Center(
            child: Form(
              key: formKey,
              child: DigitDisplayFormTextField(
                controller: controller,
                onSaved: (value) => saved = value,
              ),
            ),
          ),
        ),
      );

      formKey.currentState!.save();
      expect(saved, 7);
    });

    testWidgets('runs the validator against the initial value', (tester) async {
      final controller = DigitDisplayController(3);
      addTearDown(controller.dispose);
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        createTestApp(
          home: Center(
            child: Form(
              key: formKey,
              child: DigitDisplayFormTextField(
                controller: controller,
                validator: (value) => (value ?? 0) < 10 ? 'too low' : null,
              ),
            ),
          ),
        ),
      );

      expect(formKey.currentState!.validate(), false);
    });
  });

  group('SingleDigitText', () {
    testWidgets('renders the digit in the seven-segment font', (tester) async {
      await tester.pumpWidget(
        createTestApp(home: const Center(child: SingleDigitText(digit: 7))),
      );

      final text = tester.widget<Text>(find.text('7'));
      expect(text.style?.fontFamily, kDigitDisplayFontName);
      expect(text.style?.fontWeight, FontWeight.bold);
    });

    test('only accepts a single digit', () {
      expect(() => SingleDigitText(digit: 10), throwsAssertionError);
      expect(() => SingleDigitText(digit: -1), throwsAssertionError);
      expect(() => SingleDigitText(digit: 0), returnsNormally);
      expect(() => SingleDigitText(digit: 9), returnsNormally);
    });
  });

  testWidgets('golden: an hourmeter with an active digit', (tester) async {
    await setupGolden(tester);
    final controller = DigitDisplayController(1234.56, 5);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      createTestApp(
        home: Center(
          child: goldenBox(
            ColoredBox(
              color: const Color(0xFFFFFFFF),
              // the digits are Containers with an alignment, so they stretch to
              // whatever height they are given: bound it as a form row would
              child: SizedBox(
                width: 300,
                height: 60,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: DigitDisplayTextField(
                    controller: controller,
                    fontSize: 32,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(kGoldenBoxKey),
      matchesGoldenFile('goldens/digit_display_active.png'),
      skip: !Platform.isLinux,
    );
  });
}
