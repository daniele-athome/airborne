import 'package:airborne/helpers/cupertinoplus.dart';
import 'package:airborne/helpers/utils.dart';
import 'package:cupertino_calendar_picker/cupertino_calendar_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/app.dart';

void main() {
  /// Pumps [child] on cupertino and hands back a context under it.
  Future<BuildContext> pumpCupertino(
    WidgetTester tester,
    Widget child, {
    Brightness brightness = Brightness.light,
  }) async {
    late BuildContext captured;
    await tester.pumpWidget(
      createTestApp(
        platform: TargetPlatform.iOS,
        brightness: brightness,
        home: Builder(
          builder: (context) {
            captured = context;
            return Center(child: child);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return captured;
  }

  group('kCupertinoDialogScaffoldBackgroundColor', () {
    testWidgets('is a shade darker than white in light mode', (tester) async {
      final context = await pumpCupertino(tester, const SizedBox.shrink());

      final color = kCupertinoDialogScaffoldBackgroundColor(
        context,
      ).resolveFrom(context);
      expect(color.toARGB32(), 0xFFF2F2F7);
    });

    testWidgets('follows the scaffold in dark mode', (tester) async {
      final context = await pumpCupertino(
        tester,
        const SizedBox.shrink(),
        brightness: Brightness.dark,
      );

      final color = kCupertinoDialogScaffoldBackgroundColor(
        context,
      ).resolveFrom(context);
      expect(
        color.toARGB32(),
        CupertinoTheme.of(context).scaffoldBackgroundColor.toARGB32(),
      );
      expect(color.toARGB32(), isNot(0xFFF2F2F7));
    });
  });

  group('buildCupertinoFormRowDivider', () {
    testWidgets('indents the short one only', (tester) async {
      for (final short in [true, false]) {
        late Widget divider;
        await pumpCupertino(
          tester,
          Builder(
            builder: (context) {
              divider = buildCupertinoFormRowDivider(context, short);
              return divider;
            },
          ),
        );

        final container = divider as Container;
        expect(
          container.margin,
          short ? const EdgeInsetsDirectional.only(start: 15.0) : isNull,
          reason: 'short: $short',
        );
      }
    });

    testWidgets('is a hairline on the current screen', (tester) async {
      late Widget divider;
      final context = await pumpCupertino(
        tester,
        Builder(
          builder: (context) {
            divider = buildCupertinoFormRowDivider(context, false);
            return divider;
          },
        ),
      );

      final ratio = MediaQuery.of(context).devicePixelRatio;
      expect((divider as Container).constraints?.maxHeight, 1.0 / ratio);
    });
  });

  group('CupertinoInkWell', () {
    Color? backgroundOf(WidgetTester tester) => tester
        .widget<Container>(
          find.descendant(
            of: find.byType(CupertinoInkWell),
            matching: find.byType(Container),
          ),
        )
        .color;

    testWidgets('reports taps and shows the child', (tester) async {
      var taps = 0;
      await pumpCupertino(
        tester,
        CupertinoInkWell(
          onPressed: () => taps++,
          child: const Text('press me'),
        ),
      );

      expect(find.text('press me'), findsOneWidget);
      await tester.tap(find.text('press me'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('fills in while held down', (tester) async {
      await pumpCupertino(
        tester,
        CupertinoInkWell(
          onPressed: () {},
          backgroundColor: const Color(0xFFFFFFFF),
          child: const Text('press me'),
        ),
      );

      expect(backgroundOf(tester)?.toARGB32(), 0xFFFFFFFF);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('press me')),
      );
      await tester.pump();
      expect(backgroundOf(tester)?.toARGB32(), isNot(0xFFFFFFFF));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(backgroundOf(tester)?.toARGB32(), 0xFFFFFFFF);
    });

    testWidgets('stays put when it has nothing to do', (tester) async {
      await pumpCupertino(
        tester,
        const CupertinoInkWell(
          onPressed: null,
          backgroundColor: Color(0xFFFFFFFF),
          child: Text('press me'),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('press me')),
      );
      await tester.pump();
      expect(backgroundOf(tester)?.toARGB32(), 0xFFFFFFFF);
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  testWidgets('CupertinoFormRowContainer is at least a tap target tall', (
    tester,
  ) async {
    await pumpCupertino(
      tester,
      const CupertinoFormRowContainer(child: Text('row')),
    );

    final size = tester.getSize(find.byType(CupertinoFormRowContainer));
    expect(
      size.height,
      greaterThanOrEqualTo(kMinInteractiveDimensionCupertino),
    );
  });

  group('CupertinoFormButtonRow', () {
    testWidgets('shows the prefix and the child, and reports taps', (
      tester,
    ) async {
      var taps = 0;
      await pumpCupertino(
        tester,
        CupertinoFormButtonRow(
          prefix: const Text('Pilot'),
          onPressed: () => taps++,
          child: const Text('Anna'),
        ),
      );

      expect(find.text('Pilot'), findsOneWidget);
      expect(find.text('Anna'), findsOneWidget);
      expect(find.byType(CupertinoInkWell), findsOneWidget);

      await tester.tap(find.text('Anna'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('shows the helper and the error when given', (tester) async {
      await pumpCupertino(
        tester,
        CupertinoFormButtonRow(
          onPressed: () {},
          helper: const Text('pick one'),
          error: const Text('nobody picked'),
          child: const Text('Anna'),
        ),
      );

      expect(find.text('pick one'), findsOneWidget);
      expect(find.text('nobody picked'), findsOneWidget);
    });
  });

  group('CupertinoDateTimeFormFieldRow', () {
    FormFieldState<DateTime> fieldOf(WidgetTester tester) =>
        tester.state<FormFieldState<DateTime>>(
          find.byType(CupertinoDateTimeFormFieldRow),
        );

    test('needs at least one of date and time', () {
      expect(
        () => CupertinoDateTimeFormFieldRow(showDate: false, showTime: false),
        throwsAssertionError,
      );
    });

    testWidgets('shows a date and a time button by default', (tester) async {
      await pumpCupertino(
        tester,
        CupertinoDateTimeFormFieldRow(initialValue: DateTime(2020, 3, 15, 14)),
      );

      expect(find.byType(CupertinoCalendarPickerButton), findsOneWidget);
      expect(find.byType(CupertinoTimePickerButton), findsOneWidget);
    });

    testWidgets('can drop either half', (tester) async {
      await pumpCupertino(
        tester,
        CupertinoDateTimeFormFieldRow(
          initialValue: DateTime(2020, 3, 15, 14),
          showTime: false,
        ),
      );
      expect(find.byType(CupertinoCalendarPickerButton), findsOneWidget);
      expect(find.byType(CupertinoTimePickerButton), findsNothing);

      await pumpCupertino(
        tester,
        CupertinoDateTimeFormFieldRow(
          initialValue: DateTime(2020, 3, 15, 14),
          showDate: false,
        ),
      );
      expect(find.byType(CupertinoCalendarPickerButton), findsNothing);
      expect(find.byType(CupertinoTimePickerButton), findsOneWidget);
    });

    testWidgets('starts from the controller when there is one', (tester) async {
      final controller = DateTimePickerController(DateTime(2020, 3, 15, 14));
      addTearDown(controller.dispose);

      await pumpCupertino(
        tester,
        CupertinoDateTimeFormFieldRow(
          controller: controller,
          // the controller wins over this
          initialValue: DateTime(1999),
        ),
      );

      expect(fieldOf(tester).value, DateTime(2020, 3, 15, 14));
    });

    testWidgets('carries a change through to the controller', (tester) async {
      final controller = DateTimePickerController(DateTime(2020, 3, 15, 14));
      addTearDown(controller.dispose);

      await pumpCupertino(
        tester,
        CupertinoDateTimeFormFieldRow(controller: controller),
      );

      fieldOf(tester).didChange(DateTime(2020, 3, 20, 9));
      await tester.pumpAndSettle();

      expect(controller.value, DateTime(2020, 3, 20, 9));
      expect(fieldOf(tester).value, DateTime(2020, 3, 20, 9));
    });

    testWidgets('follows the controller when it changes underneath', (
      tester,
    ) async {
      final controller = DateTimePickerController(DateTime(2020, 3, 15, 14));
      addTearDown(controller.dispose);

      await pumpCupertino(
        tester,
        CupertinoDateTimeFormFieldRow(controller: controller),
      );

      controller.value = DateTime(2020, 3, 20, 9);
      await tester.pumpAndSettle();

      expect(fieldOf(tester).value, DateTime(2020, 3, 20, 9));
    });

    testWidgets('goes back to where it started on reset', (tester) async {
      final controller = DateTimePickerController(DateTime(2020, 3, 15, 14));
      addTearDown(controller.dispose);

      await pumpCupertino(
        tester,
        CupertinoDateTimeFormFieldRow(controller: controller),
      );

      fieldOf(tester).didChange(DateTime(2020, 3, 20, 9));
      await tester.pumpAndSettle();

      fieldOf(tester).reset();
      await tester.pumpAndSettle();

      expect(fieldOf(tester).value, DateTime(2020, 3, 15, 14));
      expect(controller.value, DateTime(2020, 3, 15, 14));
    });

    testWidgets('reports the value on save', (tester) async {
      final formKey = GlobalKey<FormState>();
      DateTime? saved;

      await pumpCupertino(
        tester,
        Form(
          key: formKey,
          child: CupertinoDateTimeFormFieldRow(
            initialValue: DateTime(2020, 3, 15, 14),
            onSaved: (value) => saved = value,
          ),
        ),
      );

      formKey.currentState!.save();
      expect(saved, DateTime(2020, 3, 15, 14));
    });
  });
}
