import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';

void main() {
  late FlutterDriver driver;

  final button = find.byType('MaterialButton');

  setUpAll(() async {
    driver = await FlutterDriver.connect();
    await driver.waitUntilFirstFrameRasterized();
  });
  tearDownAll(() async {
    driver.close();
  });

  test('Dummy test', () async {
    print('DUMMY!!!');
    await driver.tap(button);
    print('TAPPED!');
  });
}
