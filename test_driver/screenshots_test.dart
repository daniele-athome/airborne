import 'package:flutter_driver/flutter_driver.dart';
import 'package:screenshots/screenshots.dart';
import 'package:test/test.dart';

void main() {
  late FlutterDriver driver;
  final config = Config();

  setUpAll(() async {
    driver = await FlutterDriver.connect();
    await driver.waitUntilFirstFrameRasterized();
  });
  tearDownAll(() async {
    driver.close();
  });

  group('Screenshots', () {
    test('Onboarding - Select pilot', () async {
      await screenshot(driver, config, '04-onboarding-pilotselect');
      await driver.tap(find.text('Anna'));
      driver.waitUntilNoTransientCallbacks();
      // TODO i18n
      await driver.tap(find.text('OK'));
    });

    test('Book flight - Calendar views', () async {
      await driver.tap(find.byValueKey('button_bookFlight_view_schedule'));
      await screenshot(driver, config, '01-bookflight-agenda');

      await driver.tap(find.byValueKey('button_bookFlight_view_month'));
      await screenshot(driver, config, '02-bookflight-month');
    });

    test('Book flight - Flight editor', () async {
      await driver.tap(find.byValueKey('button_bookFlight'));
      await screenshot(driver, config, '03-bookflight-flighteditor');
    });
  });
}
