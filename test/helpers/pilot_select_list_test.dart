import 'dart:io';

import 'package:airborne/helpers/pilot_select_list.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/app.dart';
import '../fixtures/images.dart';
import '../golden_config.dart';

void main() {
  const pilots = ['Mike', 'John', 'Claudia'];

  group('PilotSelectList', () {
    testWidgets('shows a row per pilot on both platforms', (tester) async {
      for (final platform in kTestPlatforms) {
        await tester.pumpWidget(
          createTestApp(
            platform: platform,
            // ListTile needs a Material ancestor
            home: Material(
              child: PilotSelectList(
                pilotNames: pilots,
                avatarProvider: FakeImage.new,
                onSelection: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (final name in pilots) {
          expect(find.text(name), findsOneWidget, reason: '$platform / $name');
          expect(
            find.byKey(Key('pilot_select_list:$name')),
            findsOneWidget,
            reason: '$platform / $name',
          );
        }
        expect(find.byType(CircleAvatar), findsNWidgets(pilots.length));
      }
    });

    testWidgets('reports the pilot that was tapped', (tester) async {
      for (final platform in kTestPlatforms) {
        final selected = <String>[];
        await tester.pumpWidget(
          createTestApp(
            platform: platform,
            home: Material(
              child: PilotSelectList(
                pilotNames: pilots,
                avatarProvider: FakeImage.new,
                onSelection: selected.add,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('pilot_select_list:John')));
        await tester.pumpAndSettle();
        expect(selected, ['John'], reason: '$platform');
      }
    });

    testWidgets('asks for one avatar per pilot', (tester) async {
      final asked = <String>[];
      await tester.pumpWidget(
        createTestApp(
          home: Material(
            child: PilotSelectList(
              pilotNames: pilots,
              avatarProvider: (name) {
                asked.add(name);
                return FakeImage(name);
              },
              onSelection: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(asked, pilots);
    });
  });

  group('createPilotSelectDialog', () {
    /// Opens the dialog and returns what it eventually answers.
    Future<Future<String?>> openDialog(
      WidgetTester tester,
      TargetPlatform platform,
    ) async {
      late Future<String?> result;
      await tester.pumpWidget(
        createTestApp(
          platform: platform,
          home: Builder(
            builder: (context) => Center(
              child: GestureDetector(
                onTap: () => result = createPilotSelectDialog(
                  context: context,
                  pilotNames: pilots,
                  title: 'Pick a pilot',
                  avatarProvider: FakeImage.new,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('answers with the pilot that was picked', (tester) async {
      for (final platform in kTestPlatforms) {
        final result = await openDialog(tester, platform);

        expect(find.text('Pick a pilot'), findsOneWidget, reason: '$platform');
        expect(find.text('Claudia'), findsOneWidget, reason: '$platform');

        await tester.tap(find.byKey(const Key('pilot_select_list:Claudia')));
        await tester.pumpAndSettle();

        expect(await result, 'Claudia', reason: '$platform');
        expect(find.text('Pick a pilot'), findsNothing, reason: '$platform');
      }
    });

    testWidgets('opens a full page on cupertino and a dialog on material', (
      tester,
    ) async {
      await openDialog(tester, TargetPlatform.iOS);
      expect(find.byType(CupertinoPageScaffold), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      await openDialog(tester, TargetPlatform.android);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('answers with nothing when dismissed', (tester) async {
      final result = await openDialog(tester, TargetPlatform.android);

      // the barrier outside the dialog
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(await result, isNull);
    });
  });

  // The text is Roboto standing in for San Francisco, see font_loader.dart: the
  // glyphs are not what an iPhone draws, the layout around them is.
  testWidgets('golden: the cupertino pilot list', (tester) async {
    await setupGolden(tester);

    await tester.pumpWidget(
      createTestApp(
        platform: TargetPlatform.iOS,
        // Center so the boundary shrinks to the content instead of the screen
        home: Center(
          child: goldenBox(
            SizedBox(
              width: 320,
              height: 180,
              child: PilotSelectList(
                pilotNames: pilots,
                avatarProvider: FakeImage.new,
                onSelection: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(kGoldenBoxKey),
      matchesGoldenFile('goldens/pilot_select_list_cupertino.png'),
      skip: !Platform.isLinux,
    );
  });
}
