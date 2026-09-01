import 'dart:io';

import 'package:airborne/models/flight_log_models.dart';
import 'package:airborne/screens/flight_log/flight_log_list.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:mockito/mockito.dart';

import '../../generate_mocks.mocks.dart';

void main() {
  FlightLogItem buildItem(int id) => FlightLogItem(
    id.toString(),
    DateTime.parse('2023-10-27T10:00:00Z'),
    'Sara',
    'Fly@localhost',
    'Fly@localhost',
    1238 + id,
    1239 + id,
    null,
    null,
    null,
  );

  /// Stubs a service holding [pageCount] pages of 2 items each.
  MockFlightLogBookService mockService(int pageCount) {
    final service = MockFlightLogBookService();
    var remaining = pageCount;
    var nextId = 0;
    when(service.reset()).thenAnswer((_) async {
      remaining = pageCount;
      nextId = 0;
    });
    when(service.hasMoreData()).thenAnswer((_) => remaining > 0);
    when(service.fetchItems()).thenAnswer((_) async {
      remaining--;
      return [buildItem(nextId++), buildItem(nextId++)];
    });
    return service;
  }

  group('Flight log paging', () {
    test('Fetches pages until the service runs out of data', () async {
      final service = mockService(2);
      final controller = FlightLogListController(service);
      addTearDown(controller.dispose);

      controller.fetchNextPage();
      await pumpEventQueue();
      expect(controller.items!.length, 2);
      expect(controller.hasNextPage, true);

      controller.fetchNextPage();
      await pumpEventQueue();
      expect(controller.items!.length, 4);

      // no more data: the listing completes without another fetch
      controller.fetchNextPage();
      await pumpEventQueue();
      expect(controller.items!.length, 4);
      expect(controller.hasNextPage, false);
      verify(service.fetchItems()).called(2);
      verify(service.reset()).called(1);
    });

    test('Items are displayed in reverse order', () async {
      final controller = FlightLogListController(mockService(1));
      addTearDown(controller.dispose);

      controller.fetchNextPage();
      await pumpEventQueue();
      expect(controller.items!.map((item) => item.id), ['1', '0']);
      expect(controller.lastEndHourMeter, 1240);
    });

    test('Refresh restarts from the first page', () async {
      final service = mockService(1);
      final controller = FlightLogListController(service);
      addTearDown(controller.dispose);

      controller.fetchNextPage();
      await pumpEventQueue();
      expect(controller.loaded, true);

      controller.refresh();
      expect(controller.loaded, false);

      controller.fetchNextPage();
      await pumpEventQueue();
      expect(controller.items!.length, 2);
      // the service cursor was reset again
      verify(service.reset()).called(2);
    });

    test('A failed page can be retried any number of times', () async {
      final service = MockFlightLogBookService();
      var remaining = 3;
      var failing = false;
      when(service.reset()).thenAnswer((_) async {});
      when(service.hasMoreData()).thenAnswer((_) => remaining > 0);
      when(service.fetchItems()).thenAnswer((_) async {
        // the service keeps its cursor when a fetch fails
        if (failing) throw const SocketException('No network');
        remaining--;
        return [buildItem(0)];
      });
      final controller = FlightLogListController(service);
      addTearDown(controller.dispose);

      controller.fetchNextPage();
      await pumpEventQueue();
      expect(controller.status, PagingStatus.ongoing);

      failing = true;
      for (var retry = 0; retry < 5; retry++) {
        controller.fetchNextPage();
        await pumpEventQueue();
        // the new page error indicator must stay on screen
        expect(controller.status, PagingStatus.subsequentPageError);
      }

      failing = false;
      controller.fetchNextPage();
      await pumpEventQueue();
      expect(controller.items!.length, 2);
      expect(controller.status, PagingStatus.ongoing);
    });

    test('A failed first page keeps the error and can be retried', () async {
      final service = MockFlightLogBookService();
      var failing = true;
      when(service.reset()).thenAnswer((_) async {
        if (failing) {
          throw const FormatException('No data found on sheet.');
        }
      });
      when(service.hasMoreData()).thenAnswer((_) => !failing);
      when(service.fetchItems()).thenAnswer((_) async => [buildItem(0)]);
      final controller = FlightLogListController(service);
      addTearDown(controller.dispose);

      controller.fetchNextPage();
      await pumpEventQueue();
      expect(controller.error, isA<FormatException>());
      expect(controller.status, PagingStatus.firstPageError);

      failing = false;
      controller.fetchNextPage();
      await pumpEventQueue();
      expect(controller.error, null);
      expect(controller.items!.length, 1);
    });
  });
}
