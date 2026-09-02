import 'dart:async';
import 'dart:io';

import 'package:airborne/helpers/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../fixtures/app.dart';
import '../fixtures/path_provider.dart';
import '../generate_mocks.mocks.dart';

void main() {
  setUpAll(tz_data.initializeTimeZones);

  group('getExceptionMessage', () {
    test('unwraps the exceptions the app throws', () {
      expect(getExceptionMessage(Exception("test message")), "test message");
      const osError = OSError("os error message");
      expect(
        getExceptionMessage(const SocketException("ciaone", osError: osError)),
        "os error message",
      );
      expect(getExceptionMessage(const SocketException("ciaone")), "ciaone");
      expect(
        getExceptionMessage(LocationNotFoundException('no such zone')),
        'no such zone',
      );
    });

    test('reads the message of anything that has one', () {
      expect(
        getExceptionMessage(const FormatException('bad input')),
        'bad input',
      );
      expect(getExceptionMessage(TimeoutException('too slow')), 'too slow');
    });

    test('falls back to toString for anything else', () {
      expect(getExceptionMessage('a bare string'), 'a bare string');
      expect(getExceptionMessage(42), '42');
    });
  });

  group('number and string helpers', () {
    test('roundDouble keeps the requested decimals', () {
      expect(roundDouble(1.2345, 2), 1.23);
      expect(roundDouble(1.235, 2), 1.24);
      expect(roundDouble(1.0, 2), 1.0);
      expect(roundDouble(-1.2345, 1), -1.2);
      expect(roundDouble(1.9, 0), 2.0);
    });

    test('NumberFormat.tryParse returns null instead of throwing', () {
      final formatter = NumberFormat.decimalPattern('en');
      expect(formatter.tryParse('1,234.5'), 1234.5);
      expect(formatter.tryParse('nope'), isNull);
      expect(formatter.tryParse(''), isNull);
    });

    test('capitalize upper-cases the first character', () {
      expect('hello'.capitalize(), 'Hello');
      expect('Hello'.capitalize(), 'Hello');
      expect('a'.capitalize(), 'A');
      expect(''.capitalize(), '');
      // leading whitespace is trimmed first
      expect('  hello'.capitalize(), 'Hello');
      expect('1st'.capitalize(), '1st');
    });
  });

  group('flight time helpers', () {
    test('Duration.toFlightTimeSpec', () {
      expect(Duration(minutes: 0).toFlightTimeSpec(), "0h 00m");
      expect(Duration(minutes: 10).toFlightTimeSpec(), "0h 10m");
      expect(Duration(minutes: 60).toFlightTimeSpec(), "1h 00m");
      expect(Duration(minutes: 65).toFlightTimeSpec(), "1h 05m");
      expect(Duration(minutes: 123).toFlightTimeSpec(), "2h 03m");
      expect(Duration(minutes: 605).toFlightTimeSpec(), "10h 05m");
    });

    test('num.toMinutes reads a hourmeter reading', () {
      expect(1.76.toMinutes(100), 136);
      expect(1.toMinutes(100), 60);
      expect(1.3.toMinutes(100), 90);
      expect(1.5.toMinutes(60), 90);
      expect(0.toMinutes(60), 0);
      // the decimals are hundredths of an hour, so they can reach 100
      expect(1.999.toMinutes(100), 160);
    });
  });

  group('DateHelpers', () {
    test('recognises today, yesterday and tomorrow', () {
      final now = DateTime.now();
      expect(now.isToday, true);
      expect(now.isYesterday, false);
      expect(now.isTomorrow, false);

      final yesterday = now.subtract(const Duration(days: 1));
      expect(yesterday.isYesterday, true);
      expect(yesterday.isToday, false);

      final tomorrow = now.add(const Duration(days: 1));
      expect(tomorrow.isTomorrow, true);
      expect(tomorrow.isToday, false);
    });

    test('compares the whole date, not just the day', () {
      final now = DateTime.now();
      final aYearAgo = DateTime(now.year - 1, now.month, now.day);
      expect(aYearAgo.isToday, false);
      expect(aYearAgo.isYesterday, false);
      expect(aYearAgo.isTomorrow, false);
    });
  });

  group('formatMarkdown', () {
    /// Flattens a span into its (text, bold) pieces.
    List<(String, bool)> piecesOf(InlineSpan span) {
      final root = span as TextSpan;
      final children = root.children;
      bool isBold(TextSpan s) => s.style?.fontWeight == FontWeight.bold;
      if (children == null) {
        return [(root.text ?? '', isBold(root))];
      }
      return children
          .cast<TextSpan>()
          .map((s) => (s.text ?? '', isBold(s)))
          .toList();
    }

    test('leaves text without markup alone', () {
      expect(piecesOf(formatMarkdown('plain text')), [('plain text', false)]);
      expect(piecesOf(formatMarkdown('')), [('', false)]);
    });

    test('splits around a bold section', () {
      expect(piecesOf(formatMarkdown('**bold** rest')), [
        ('bold', true),
        (' rest', false),
      ]);
      expect(piecesOf(formatMarkdown('before **bold** after')), [
        ('before ', false),
        ('bold', true),
        (' after', false),
      ]);
      expect(piecesOf(formatMarkdown('before **bold**')), [
        ('before ', false),
        ('bold', true),
      ]);
    });

    test('ignores unbalanced markers', () {
      expect(piecesOf(formatMarkdown('**not closed')), [
        ('**not closed', false),
      ]);
      expect(piecesOf(formatMarkdown('a * b')), [('a * b', false)]);
    });

    test('only handles the first bold section', () {
      // documented limitation of the naive implementation
      expect(piecesOf(formatMarkdown('**one** and **two**')), [
        ('one', true),
        (' and **two**', false),
      ]);
    });
  });

  group('getSunTimes', () {
    test('computes sunrise and sunset at the equator', () {
      setLocalLocation(UTC);
      expect(
        getSunTimes(0, 0, DateTime.utc(2020), UTC),
        SunTimes(
          TZDateTime.parse(UTC, "2020-01-01 05:59:35.000Z"),
          TZDateTime.parse(UTC, "2020-01-01 18:07:03.000Z"),
        ),
      );
    });

    test('reports the times in the given time zone', () {
      final rome = getLocation('Europe/Rome');
      final times = getSunTimes(
        41.9028,
        12.4964,
        DateTime.utc(2020, 6, 21),
        rome,
      );

      expect(times.sunrise.location, rome);
      expect(times.sunset.location, rome);
      expect(times.sunrise.isBefore(times.sunset), true);
      // summer solstice in Rome, in CEST
      expect(times.sunrise.hour, 5);
      expect(times.sunset.hour, 20);
    });

    test('SunTimes compares by value', () {
      final a = SunTimes(
        TZDateTime.parse(UTC, "2020-01-01 06:00:00.000Z"),
        TZDateTime.parse(UTC, "2020-01-01 18:00:00.000Z"),
      );
      final b = SunTimes(
        TZDateTime.parse(UTC, "2020-01-01 06:00:00.000Z"),
        TZDateTime.parse(UTC, "2020-01-01 18:00:00.000Z"),
      );
      final c = SunTimes(
        TZDateTime.parse(UTC, "2020-01-01 07:00:00.000Z"),
        TZDateTime.parse(UTC, "2020-01-01 18:00:00.000Z"),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('BuildContextExtension', () {
    testWidgets('reports the locale without a country', (tester) async {
      final context = await pumpTestContext(tester);
      expect(context.locale, const Locale('en'));
      expect(context.localeString, 'en');
    });

    testWidgets('appends the country code when there is one', (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        createTestApp(
          home: Builder(
            builder: (context) => Localizations.override(
              context: context,
              locale: const Locale('en', 'US'),
              child: Builder(
                builder: (inner) {
                  captured = inner;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      expect(captured.localeString, 'en_US');
    });
  });

  group('localized formatting', () {
    testWidgets('getRelativeDateString names the nearby days', (tester) async {
      final context = await pumpTestContext(tester);
      final formatter = DateFormat.yMd('en');
      final now = DateTime.now();

      expect(
        getRelativeDateString(context, formatter, now),
        'Today, ${formatter.format(now)}',
      );
      final yesterday = now.subtract(const Duration(days: 1));
      expect(
        getRelativeDateString(context, formatter, yesterday),
        'Yesterday, ${formatter.format(yesterday)}',
      );
      final tomorrow = now.add(const Duration(days: 1));
      expect(
        getRelativeDateString(context, formatter, tomorrow),
        'Tomorrow, ${formatter.format(tomorrow)}',
      );
      final other = DateTime(2020, 3, 15);
      expect(
        getRelativeDateString(context, formatter, other),
        formatter.format(other),
      );
    });

    testWidgets('formatFlightTimeDuration grows past the hour', (tester) async {
      final context = await pumpTestContext(tester);

      expect(
        formatFlightTimeDuration(context, const Duration(minutes: 30)),
        'Total flight time: 30 minutes',
      );
      expect(
        formatFlightTimeDuration(context, const Duration(minutes: 1)),
        'Total flight time: 1 minute',
      );
      expect(
        formatFlightTimeDuration(context, const Duration(minutes: 90)),
        'Total flight time: 90 minutes (1h 30m)',
      );
      // exactly an hour already uses the extended form
      expect(
        formatFlightTimeDuration(context, const Duration(minutes: 60)),
        'Total flight time: 60 minutes (1h 00m)',
      );
    });
  });

  group('platform theming', () {
    testWidgets('getBrightness follows the platform theme', (tester) async {
      for (final platform in kTestPlatforms) {
        for (final brightness in Brightness.values) {
          final context = await pumpTestContext(
            tester,
            platform: platform,
            brightness: brightness,
          );
          expect(
            getBrightness(context),
            brightness,
            reason: '$platform / $brightness',
          );
        }
      }
    });

    testWidgets('getModalBarrierColor dims differently per platform', (
      tester,
    ) async {
      final material = await pumpTestContext(tester);
      expect(getModalBarrierColor(material), Colors.black54);

      final light = await pumpTestContext(tester, platform: TargetPlatform.iOS);
      expect(getModalBarrierColor(light).toARGB32(), 0xCCF2F2F2);

      final dark = await pumpTestContext(
        tester,
        platform: TargetPlatform.iOS,
        brightness: Brightness.dark,
      );
      expect(getModalBarrierColor(dark).toARGB32(), 0xBF1E1E1E);
    });
  });

  group('dialogs', () {
    /// Pumps a button running [action] with a context that can show dialogs.
    Future<void> pumpAction(
      WidgetTester tester,
      void Function(BuildContext context) action, {
      TargetPlatform platform = TargetPlatform.android,
    }) async {
      await tester.pumpWidget(
        createTestApp(
          platform: platform,
          home: Builder(
            builder: (context) => Center(
              child: GestureDetector(
                onTap: () => action(context),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
    }

    testWidgets('showError shows the message and closes on OK', (tester) async {
      await pumpAction(tester, (context) => showError(context, 'it broke'));

      expect(find.text('Error'), findsOneWidget);
      expect(find.text('it broke'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('it broke'), findsNothing);
    });

    testWidgets('showConfirm runs the callback only on OK', (tester) async {
      var confirmed = 0;
      await pumpAction(
        tester,
        (context) => showConfirm(
          context: context,
          text: 'delete this?',
          title: 'Careful',
          okCallback: () => confirmed++,
        ),
      );

      expect(find.text('Careful'), findsOneWidget);
      expect(find.text('delete this?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(confirmed, 0);
      expect(find.text('delete this?'), findsNothing);

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(confirmed, 1);
      expect(find.text('delete this?'), findsNothing);
    });

    testWidgets('showConfirm marks the destructive action on cupertino', (
      tester,
    ) async {
      await pumpAction(
        tester,
        (context) => showConfirm(
          context: context,
          text: 'delete this?',
          title: 'Careful',
          okCallback: () {},
          destructiveOk: true,
        ),
        platform: TargetPlatform.iOS,
      );

      final ok = tester.widget<CupertinoDialogAction>(
        find.widgetWithText(CupertinoDialogAction, 'OK'),
      );
      expect(ok.isDestructiveAction, true);
    });
  });

  group('openUrl', () {
    late UrlLauncherPlatform previous;

    setUp(() => previous = UrlLauncherPlatform.instance);
    tearDown(() => UrlLauncherPlatform.instance = previous);

    Future<bool> tapOpenUrl(WidgetTester tester) async {
      late Future<bool> result;
      await tester.pumpWidget(
        createTestApp(
          home: Builder(
            builder: (context) => Center(
              child: GestureDetector(
                onTap: () => result = openUrl(context, 'https://example.com/'),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('opens the url in an external application', (tester) async {
      final launcher = _FakeUrlLauncher();
      UrlLauncherPlatform.instance = launcher;

      expect(await tapOpenUrl(tester), true);
      expect(launcher.launched, ['https://example.com/']);
      expect(launcher.modes.single, PreferredLaunchMode.externalApplication);
      expect(find.text('Error'), findsNothing);
    });

    testWidgets('reports a browser that will not open', (tester) async {
      UrlLauncherPlatform.instance = _FakeUrlLauncher(
        onLaunch: (_) => throw Exception('no browser'),
      );

      expect(await tapOpenUrl(tester), false);
      expect(find.text('Error'), findsOneWidget);
      expect(find.text('Cannot open a browser.'), findsOneWidget);
    });

    testWidgets('stays quiet when the platform just declines', (tester) async {
      UrlLauncherPlatform.instance = _FakeUrlLauncher(onLaunch: (_) => false);

      expect(await tapOpenUrl(tester), false);
      expect(find.text('Error'), findsNothing);
    });
  });

  group('DownloadProvider', () {
    useFakePathProvider();

    /// A client answering [statusCode] with [body], recording what it was asked.
    ({MockHttpClient client, List<Uri> urls}) fakeClient({
      int statusCode = 200,
      List<int> body = const [1, 2, 3],
    }) {
      final urls = <Uri>[];
      final client = MockHttpClient();
      when(client.getUrl(any)).thenAnswer((invocation) async {
        urls.add(invocation.positionalArguments.first as Uri);
        return _FakeRequest(_FakeResponse(statusCode: statusCode, body: body));
      });
      return (client: client, urls: urls);
    }

    test('writes the download into the temporary directory', () async {
      final tmpDir = await getTemporaryDirectory();
      tmpDir.createSync(recursive: true);
      final fake = fakeClient(body: [7, 8, 9]);
      final provider = DownloadProvider(() => fake.client);

      final file = await provider.downloadToFile(
        'https://example.com/a1234.zip',
        'aircraft.zip',
        null,
        null,
        true,
      );

      expect(file.path, path.join(tmpDir.path, 'aircraft.zip'));
      expect(file.readAsBytesSync(), [7, 8, 9]);
      expect(fake.urls.single, Uri.parse('https://example.com/a1234.zip'));
      verify(fake.client.connectionTimeout = kNetworkRequestTimeout).called(1);
    });

    test('writes into the support directory when not temporary', () async {
      final supportDir = await getApplicationSupportDirectory();
      supportDir.createSync(recursive: true);
      final provider = DownloadProvider(() => fakeClient().client);

      final file = await provider.downloadToFile(
        'https://example.com/a1234.zip',
        'aircraft.zip',
        null,
        null,
        false,
      );

      expect(file.path, path.join(supportDir.path, 'aircraft.zip'));
    });

    test('sends credentials only when both are given', () async {
      (await getTemporaryDirectory()).createSync(recursive: true);

      final withBoth = fakeClient();
      await DownloadProvider(() => withBoth.client).downloadToFile(
        'https://example.com/a.zip',
        'a.zip',
        'joe',
        'secret',
        true,
      );
      verify(
        withBoth.client.addCredentials(
          any,
          '',
          argThat(isA<HttpClientBasicCredentials>()),
        ),
      ).called(1);

      final withoutPassword = fakeClient();
      await DownloadProvider(
        () => withoutPassword.client,
      ).downloadToFile('https://example.com/a.zip', 'a.zip', 'joe', null, true);
      verifyNever(withoutPassword.client.addCredentials(any, any, any));
    });

    test('refuses anything that is not a 200', () async {
      (await getTemporaryDirectory()).createSync(recursive: true);
      final provider = DownloadProvider(
        () => fakeClient(statusCode: 404).client,
      );

      await expectLater(
        provider.downloadToFile(
          'https://example.com/a.zip',
          'a.zip',
          null,
          null,
          true,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Download error (404)'),
          ),
        ),
      );
    });

    test('hides a socket failure behind a timeout', () async {
      final client = MockHttpClient();
      when(
        client.getUrl(any),
      ).thenThrow(const SocketException('connection refused'));
      final provider = DownloadProvider(() => client);

      await expectLater(
        provider.downloadToFile(
          'https://example.com/a.zip',
          'a.zip',
          null,
          null,
          true,
        ),
        throwsA(
          isA<TimeoutException>().having(
            (e) => e.message,
            'message',
            'connection refused',
          ),
        ),
      );
    });
  });

  group('paging indicators', () {
    testWidgets('FirstPageExceptionIndicator shows what it is given', (
      tester,
    ) async {
      for (final platform in kTestPlatforms) {
        await tester.pumpWidget(
          createTestApp(
            platform: platform,
            home: const FirstPageExceptionIndicator(title: 'No luck'),
          ),
        );
        expect(find.text('No luck'), findsOneWidget);
        expect(find.byKey(const Key('button_error_retry')), findsNothing);

        await tester.pumpWidget(
          createTestApp(
            platform: platform,
            home: const FirstPageExceptionIndicator(
              title: 'No luck',
              message: 'try later',
            ),
          ),
        );
        expect(find.text('try later'), findsOneWidget);
      }
    });

    testWidgets('FirstPageExceptionIndicator retries on demand', (
      tester,
    ) async {
      for (final platform in kTestPlatforms) {
        var retries = 0;
        await tester.pumpWidget(
          createTestApp(
            platform: platform,
            home: FirstPageExceptionIndicator(
              title: 'No luck',
              onTryAgain: () => retries++,
            ),
          ),
        );

        final button = find.byKey(const Key('button_error_retry'));
        expect(button, findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);

        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(retries, 1, reason: '$platform');
      }
    });

    testWidgets('NewPageErrorIndicator retries on tap', (tester) async {
      for (final platform in kTestPlatforms) {
        var retries = 0;
        await tester.pumpWidget(
          createTestApp(
            platform: platform,
            // InkWell needs a Material ancestor
            home: Material(
              child: NewPageErrorIndicator(
                message: 'could not load',
                onTap: () => retries++,
              ),
            ),
          ),
        );

        expect(find.text('could not load'), findsOneWidget);
        expect(find.byIcon(Icons.refresh), findsOneWidget);

        await tester.tap(find.text('could not load'));
        await tester.pumpAndSettle();
        expect(retries, 1, reason: '$platform');
      }
    });

    testWidgets('FooterTile centres its child', (tester) async {
      await tester.pumpWidget(
        createTestApp(home: const FooterTile(child: Text('footer'))),
      );
      expect(find.text('footer'), findsOneWidget);
      expect(
        find.ancestor(of: find.text('footer'), matching: find.byType(Center)),
        findsWidgets,
      );
    });
  });

  test('DateTimePickerController notifies on change', () {
    final controller = DateTimePickerController(null);
    addTearDown(controller.dispose);

    var notified = 0;
    controller.addListener(() => notified++);

    controller.value = DateTime(2026, 9, 1);
    expect(notified, 1);
    expect(controller.value, DateTime(2026, 9, 1));

    // same value, no notification
    controller.value = DateTime(2026, 9, 1);
    expect(notified, 1);
  });
}

/// A [UrlLauncherPlatform] that records what it was asked to open.
class _FakeUrlLauncher extends UrlLauncherPlatform {
  _FakeUrlLauncher({this.onLaunch});

  /// Decides the outcome of a launch. Defaults to reporting success.
  final Object Function(String url)? onLaunch;

  final List<String> launched = [];
  final List<PreferredLaunchMode> modes = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    modes.add(options.mode);
    return onLaunch == null ? true : onLaunch!(url) as bool;
  }
}

/// A request that answers with a canned response.
class _FakeRequest extends Mock implements HttpClientRequest {
  _FakeRequest(this._response);

  final HttpClientResponse _response;

  @override
  Future<HttpClientResponse> close() async => _response;
}

/// A response handing out [body] once, enough for [DownloadProvider].
class _FakeResponse extends Mock implements HttpClientResponse {
  _FakeResponse({this.statusCode = 200, List<int> body = const []})
    : _body = body;

  @override
  final int statusCode;

  final List<int> _body;

  @override
  Future<dynamic> pipe(StreamConsumer<List<int>> consumer) =>
      Stream<List<int>>.value(_body).pipe(consumer);
}
