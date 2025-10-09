import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

Future<void> setupGolden(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 600));
}
