import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';
import 'package:process/process.dart';

Future<void> main() async {
  final processManager = LocalProcessManager();

  await integrationDriver(
    onScreenshot: (String screenshotName, List<int> screenshotBytes, [Map<String, Object?>? args]) async {
      final imageFilename = '.screenshots/$screenshotName.png';
      final image = await File(imageFilename).create(recursive: true);
      image.writeAsBytesSync(screenshotBytes);

      final result = await processManager.run([
        "./screenshots/resources/script/process-screenshot.sh",
        imageFilename,
        args!['platform'] as String,
        args['device'] as String,
        args['locale'] as String,
        args['orientation'] as String,
      ]);

      // Return false if the screenshot is invalid.
      return (result.exitCode == 0);
    },
  );
}
