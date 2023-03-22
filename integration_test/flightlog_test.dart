import 'package:airborne/main.dart' as app;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nock/nock.dart';

import 'test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('flight log test', () {
    setUpAll(() async {
      await clearAppData();
      nock.init();
      mockGoogleAuthentication();
      mockGoogleSheetsApi();
      setUpDummyAircraft();
    });

    tearDownAll(() async {
      await clearAppData();
      unmockAllHttp();
    });

    testWidgets('flight log: empty log book', (WidgetTester tester) async {
      app.main();

      await tester.pumpAndSettle();

      expect(await waitForWidget(tester, find.byKey(const Key('nav_flight_log')), 10), true);
      await tester.tap(find.byKey(const Key("nav_flight_log")));
      await tester.pumpAndSettle();

      expect(tester.any(find.byKey(const Key('button_error_retry'))), true);
      // TODO expect some widgets present
      // TODO check that http interceptor was called
    });
    // TODO CRUD tests
  });

}
