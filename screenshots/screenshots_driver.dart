import 'dart:io' as dart_Platform;

import 'package:integration_test/integration_test_driver_extended.dart';
import 'package:screenshots/src/context_runner.dart' show runInContext;
import 'package:screenshots/src/globals.dart' show RunMode, DeviceType;
import 'package:screenshots/src/archive.dart' show Archive;
import 'package:screenshots/src/config.dart' as scr_Config;
import 'package:screenshots/src/screens.dart' show Screens;
import 'package:screenshots/src/image_processor.dart' show ImageProcessor;
import 'package:tool_base/tool_base.dart';

Future<void> main() async {
  final locale = dart_Platform.Platform.environment['TEST_LOCALE'];
  final device = dart_Platform.Platform.environment['TEST_DEVICE'];

  final config = scr_Config.Config(configStr: """
staging: ./.screenshots

locales:
  - $locale

devices:
  android:
    $device:
      orientation:
        - Portrait
      navbar: false

frame: false
"""
  );

  final screens = Screens();
  await screens.init();

  final imageProcessor = ImageProcessor(screens, config);
  bool first = false;

  await integrationDriver(
    onScreenshot: (String screenshotName, List<int> screenshotBytes, [Map<String, Object?>? args]) async {
      // FIXME correct path
      final image = await dart_Platform.File('.screenshots/screenshots/$screenshotName.png').create(recursive: true);
      image.writeAsBytesSync(screenshotBytes);

      if (!first) {
        first = true;
      }
      else {
        return true;
      }

      Logger verboseLogger = VerboseLogger(platform.isWindows ? WindowsStdoutLogger() : StdoutLogger());
      await runInContext<void>(() async {
        try {
          await imageProcessor.process(DeviceType.android,
              config.deviceNames.first,
              config.devices.first.orientations!.first,
              RunMode.normal,
              Archive("dummy"));
        }
        catch(e, stacktrace) {
          printError(e.toString(), stackTrace: stacktrace);
        }
      }, overrides: <Type, Generator>{
        Logger: () => verboseLogger,
      });

      // Return false if the screenshot is invalid.
      return true;
    },
  );
}
