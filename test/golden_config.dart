import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Key of the [RepaintBoundary] golden assertions capture.
const kGoldenBoxKey = Key('golden_box');

Future<void> setupGolden(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 600));
  // the surface outlives the test that set it, and a smaller one makes the
  // tests that follow lay out (and overflow) differently
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Wraps [child] in the repaint boundary golden assertions capture.
Widget goldenBox(Widget child) =>
    RepaintBoundary(key: kGoldenBoxKey, child: child);
