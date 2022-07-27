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

  Future<SerializableFinder> pageClose(String cupertinoValueKey) async {
    if (await driver.requestData('getPlatform') == 'TargetPlatform.iOS') {
      return find.byValueKey(cupertinoValueKey);
    }
    else {
      return find.byType('CloseButton');
    }
  }

  group('Screenshots', () {
    test('Onboarding - Select pilot', () async {
      await screenshot(driver, config, '50-onboarding-pilotselect');
      await driver.tap(find.text('Anna'));
      await driver.waitUntilNoTransientCallbacks();
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
      await driver.tap(await pageClose('button_bookFlightModal_close'));
    });

    test('Log book - List view', () async {
      await driver.tap(find.byValueKey('nav_flight_log'));
      await driver.waitUntilNoTransientCallbacks();
      await screenshot(driver, config, '04-logbook-list');
    });

    test('Log book - Flight editor', () async {
      await driver.tap(find.byValueKey('button_logFlight'));
      await screenshot(driver, config, '05-logbook-flighteditor');
      await driver.tap(await pageClose('button_flightLogModal_close'));
    });

    test('Activities - List view', () async {
      await driver.tap(find.byValueKey('nav_activities'));
      await driver.waitUntilNoTransientCallbacks();
      await screenshot(driver, config, '06-activities-list');
    });
  });
}
