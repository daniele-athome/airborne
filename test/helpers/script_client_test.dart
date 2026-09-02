import 'dart:async';
import 'dart:convert';

import 'package:airborne/helpers/script_client.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const url = 'https://script.google.com/macros/s/DEPLOY_ID/exec';
  const token = 'test-token';

  /// Builds a client answering with [responses], one per request received, and
  /// appending every request to [requests].
  http.Client clientAnswering(
    List<http.Response> responses, {
    List<http.Request>? requests,
  }) {
    var index = 0;
    return MockClient((request) async {
      requests?.add(request);
      if (index >= responses.length) {
        fail('unexpected request #${index + 1} to ${request.url}');
      }
      return responses[index++];
    });
  }

  ScriptClient buildClient(
    List<http.Response> responses, {
    List<http.Request>? requests,
  }) => ScriptClient(
    url: url,
    token: token,
    httpClient: clientAnswering(responses, requests: requests),
  );

  /// The envelope the script returns on success.
  http.Response okEnvelope(
    Object? data, {
    bool? replayed,
    int statusCode = 200,
  }) => http.Response(
    json.encode({
      'ok': true,
      'v': kProtocolVersion,
      'data': data,
      'replayed': ?replayed,
    }),
    statusCode,
  );

  /// The envelope the script returns on failure.
  http.Response errorEnvelope(
    ScriptErrorCode code, {
    String? message,
    String? details,
  }) => http.Response(
    json.encode({
      'ok': false,
      'v': kProtocolVersion,
      'error': {'code': code.code, 'message': ?message, 'details': ?details},
    }),
    200,
  );

  http.Response redirectTo(String location) =>
      http.Response('', 302, headers: {'location': location});

  Future<ScriptResult> invoke(
    ScriptClient client, {
    String action = 'flight-log/insert',
    String requestId = 'req-1',
    Map<String, dynamic> payload = const {'hello': 'world'},
  }) => client.invoke(action: action, requestId: requestId, payload: payload);

  /// Drives [action] inside a fake-async zone, elapsing [elapse] so that
  /// backoffs and timeouts fire, and reports how it completed.
  ({ScriptResult? result, Object? error}) runInvoke(
    FakeAsync async,
    Future<ScriptResult> Function() action, {
    Duration elapse = const Duration(seconds: 5),
  }) {
    ScriptResult? result;
    Object? error;
    unawaited(() async {
      try {
        result = await action();
      } catch (e) {
        error = e;
      }
    }());
    async.elapse(elapse);
    return (result: result, error: error);
  }

  group('ScriptErrorCode', () {
    test('parses every code the script can return', () {
      // these are the values of ERROR in server/src/10_protocol.js
      expect(
        ScriptErrorCode.fromCode('BAD_REQUEST'),
        ScriptErrorCode.badRequest,
      );
      expect(
        ScriptErrorCode.fromCode('UNAUTHORIZED'),
        ScriptErrorCode.unauthorized,
      );
      expect(ScriptErrorCode.fromCode('FORBIDDEN'), ScriptErrorCode.forbidden);
      expect(ScriptErrorCode.fromCode('NOT_FOUND'), ScriptErrorCode.notFound);
      expect(ScriptErrorCode.fromCode('BUSY'), ScriptErrorCode.busy);
      expect(
        ScriptErrorCode.fromCode('PROTOCOL_INCOMPATIBLE'),
        ScriptErrorCode.protocolIncompatible,
      );
      expect(ScriptErrorCode.fromCode('INTERNAL'), ScriptErrorCode.internal);
    });

    test('treats an unknown code as a protocol violation', () {
      expect(
        ScriptErrorCode.fromCode('SOMETHING_NEW'),
        ScriptErrorCode.malformedResponse,
      );
      expect(ScriptErrorCode.fromCode(''), ScriptErrorCode.malformedResponse);
      // codes are matched on the wire value, not on the enum name
      expect(
        ScriptErrorCode.fromCode('badRequest'),
        ScriptErrorCode.malformedResponse,
      );
    });

    test('only the synthesized codes are not from the script', () {
      final synthesized = ScriptErrorCode.values
          .where((c) => !c.isFromScript)
          .toSet();
      expect(synthesized, {
        ScriptErrorCode.notReachable,
        ScriptErrorCode.malformedResponse,
      });
    });

    test('orders by wire value', () {
      final sorted = ScriptErrorCode.values.toList()..sort();
      expect(
        sorted.map((c) => c.code),
        sorted.map((c) => c.code).toList()..sort(),
      );
      expect(
        ScriptErrorCode.badRequest.compareTo(ScriptErrorCode.busy),
        lessThan(0),
      );
      expect(
        ScriptErrorCode.busy.compareTo(ScriptErrorCode.badRequest),
        greaterThan(0),
      );
      expect(ScriptErrorCode.busy.compareTo(ScriptErrorCode.busy), 0);
    });
  });

  group('newRequestId', () {
    test('is hexadecimal', () {
      for (var i = 0; i < 20; i++) {
        expect(ScriptClient.newRequestId(), matches(RegExp(r'^[0-9a-f]+$')));
      }
    });

    test('does not repeat itself', () {
      final ids = List.generate(200, (_) => ScriptClient.newRequestId());
      expect(ids.toSet(), hasLength(ids.length));
    });
  });

  group('request envelope', () {
    test('posts the envelope to the configured url', () async {
      final requests = <http.Request>[];
      final client = buildClient([
        okEnvelope({'id': 'row-1'}),
      ], requests: requests);

      await invoke(
        client,
        action: 'flight-log/update',
        requestId: 'req-42',
        payload: {'date': '2026-09-01', 'id': 'row-1'},
      );

      expect(requests, hasLength(1));
      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url, Uri.parse(url));
      expect(
        request.headers['content-type'],
        'application/json; charset=utf-8',
      );

      final body = json.decode(request.body) as Map<String, dynamic>;
      expect(body['v'], kProtocolVersion);
      expect(body['token'], token);
      expect(body['action'], 'flight-log/update');
      expect(body['requestId'], 'req-42');
      expect(body['payload'], {'date': '2026-09-01', 'id': 'row-1'});
      // diagnostic only, so only the shape matters
      expect(body['client'], startsWith('airborne/'));
    });

    test('speaks the protocol version the server requires', () {
      // PROTOCOL_V in server/src/00_config.js
      expect(kProtocolVersion, 1);
    });

    test(
      'does not let the http client follow the redirect on its own',
      () async {
        final requests = <http.Request>[];
        final client = buildClient([
          okEnvelope({'id': 'row-1'}),
        ], requests: requests);

        await invoke(client);

        expect(requests.single.followRedirects, false);
      },
    );
  });

  group('redirect handling', () {
    test('follows a relative redirect with a GET', () async {
      final requests = <http.Request>[];
      final client = buildClient([
        redirectTo('/macros/s/DEPLOY_ID/echo'),
        okEnvelope({'id': 'row-1'}),
      ], requests: requests);

      final result = await invoke(client);

      expect(result.id, 'row-1');
      expect(requests, hasLength(2));
      expect(requests[1].method, 'GET');
      expect(
        requests[1].url,
        Uri.parse('https://script.google.com/macros/s/DEPLOY_ID/echo'),
      );
    });

    test('follows a redirect onto another host', () async {
      final requests = <http.Request>[];
      // this is what Apps Script actually does
      const target =
          'https://script.googleusercontent.com/macros/echo?user_content_key=KEY';
      final client = buildClient([
        redirectTo(target),
        okEnvelope({'id': 'row-1'}),
      ], requests: requests);

      final result = await invoke(client);

      expect(result.id, 'row-1');
      expect(requests[1].url, Uri.parse(target));
    });

    test('unwraps the POST response when there is no redirect', () async {
      final requests = <http.Request>[];
      final client = buildClient([
        okEnvelope({'id': 'row-1'}),
      ], requests: requests);

      final result = await invoke(client);

      expect(result.id, 'row-1');
      expect(requests, hasLength(1));
    });
  });

  group('response unwrapping', () {
    test('reports the entry id', () async {
      final client = buildClient([
        okEnvelope({'id': 'row-7'}),
      ]);
      final result = await invoke(client);
      expect(result.id, 'row-7');
      expect(result.replayed, false);
    });

    test('reports a replayed write', () async {
      final client = buildClient([
        okEnvelope({'id': 'row-7'}, replayed: true),
      ]);
      expect((await invoke(client)).replayed, true);
    });

    test('ignores a replayed flag that is not true', () async {
      final client = buildClient([
        http.Response(
          json.encode({
            'ok': true,
            'data': {'id': 'row-7'},
            'replayed': 'yes',
          }),
          200,
        ),
      ]);
      expect((await invoke(client)).replayed, false);
    });

    test('rejects a success that does not name the entry', () async {
      for (final data in <Object?>[
        null,
        <String, dynamic>{},
        {'id': ''},
        {'id': 42},
        'row-1',
        ['row-1'],
      ]) {
        final client = buildClient([okEnvelope(data)]);
        await expectLater(
          invoke(client),
          throwsA(
            isA<ScriptException>().having(
              (e) => e.code,
              'code',
              ScriptErrorCode.malformedResponse.code,
            ),
          ),
          reason: 'data: $data',
        );
      }
    });

    test('reports the error the script sent', () async {
      final client = buildClient([
        errorEnvelope(
          ScriptErrorCode.notFound,
          message: 'Entry row-9 not found',
          details: 'at Object.actionFlightLogDelete',
        ),
      ]);

      await expectLater(
        invoke(client),
        throwsA(
          isA<ScriptException>()
              .having((e) => e.code, 'code', 'NOT_FOUND')
              .having((e) => e.message, 'message', 'Entry row-9 not found')
              .having(
                (e) => e.details,
                'details',
                'at Object.actionFlightLogDelete',
              ),
        ),
      );
    });

    test('falls back when the error envelope carries no detail', () async {
      final client = buildClient([
        http.Response(json.encode({'ok': false}), 200),
      ]);

      await expectLater(
        invoke(client),
        throwsA(
          isA<ScriptException>()
              .having((e) => e.code, 'code', ScriptErrorCode.internal.code)
              .having((e) => e.message, 'message', 'Unknown backend error')
              .having((e) => e.details, 'details', isNull),
        ),
      );
    });

    test('falls back when the error object is empty', () async {
      final client = buildClient([
        http.Response(json.encode({'ok': false, 'error': {}}), 200),
      ]);

      await expectLater(
        invoke(client),
        throwsA(
          isA<ScriptException>()
              .having((e) => e.code, 'code', ScriptErrorCode.internal.code)
              .having((e) => e.message, 'message', 'Unknown backend error'),
        ),
      );
    });

    test('reports an error it cannot read as a protocol violation', () async {
      for (final error in <Object>[
        'boom',
        42,
        ['boom'],
      ]) {
        final client = buildClient([
          http.Response(json.encode({'ok': false, 'error': error}), 200),
        ]);

        await expectLater(
          invoke(client),
          throwsA(
            isA<ScriptException>().having(
              (e) => e.code,
              'code',
              ScriptErrorCode.malformedResponse.code,
            ),
          ),
          reason: 'error: $error',
        );
      }
    });

    test('degrades an error whose fields have the wrong type', () async {
      final client = buildClient([
        http.Response(
          json.encode({
            'ok': false,
            'error': {'code': 42, 'message': null, 'details': 7},
          }),
          200,
        ),
      ]);

      await expectLater(
        invoke(client),
        throwsA(
          isA<ScriptException>()
              .having((e) => e.code, 'code', ScriptErrorCode.internal.code)
              .having((e) => e.message, 'message', 'Unknown backend error')
              .having((e) => e.details, 'details', isNull),
        ),
      );
    });

    test('treats a missing ok flag as an error', () async {
      final client = buildClient([
        http.Response(
          json.encode({
            'data': {'id': 'row-1'},
          }),
          200,
        ),
      ]);

      await expectLater(
        invoke(client),
        throwsA(
          isA<ScriptException>().having(
            (e) => e.code,
            'code',
            ScriptErrorCode.internal.code,
          ),
        ),
      );
    });

    test('reports a non-JSON answer as unreachable', () async {
      // what a deployment with the wrong access settings serves
      final client = buildClient([
        http.Response('<!DOCTYPE html><html>Sign in</html>', 200),
      ]);

      await expectLater(
        invoke(client),
        throwsA(
          isA<ScriptException>().having(
            (e) => e.code,
            'code',
            ScriptErrorCode.notReachable.code,
          ),
        ),
      );
    });

    test(
      'reports a JSON answer that is not an object as unreachable',
      () async {
        for (final body in ['[1, 2]', '"nope"', 'null']) {
          final client = buildClient([http.Response(body, 200)]);
          await expectLater(
            invoke(client),
            throwsA(
              isA<ScriptException>().having(
                (e) => e.code,
                'code',
                ScriptErrorCode.notReachable.code,
              ),
            ),
            reason: 'body: $body',
          );
        }
      },
    );

    test('ignores the HTTP status code', () async {
      // the script answers 200 on every path, so the status is not a signal
      final client = buildClient([
        okEnvelope({'id': 'row-1'}, statusCode: 500),
      ]);
      expect((await invoke(client)).id, 'row-1');
    });
  });

  group('busy retry', () {
    test('retries once and succeeds', () {
      fakeAsync((async) {
        final requests = <http.Request>[];
        final client = buildClient([
          errorEnvelope(ScriptErrorCode.busy),
          okEnvelope({'id': 'row-1'}),
        ], requests: requests);

        final outcome = runInvoke(async, () => invoke(client));

        expect(outcome.error, isNull);
        expect(outcome.result?.id, 'row-1');
        expect(requests, hasLength(2));
      });
    });

    test('replays the same requestId on the retry', () {
      fakeAsync((async) {
        final requests = <http.Request>[];
        final client = buildClient([
          errorEnvelope(ScriptErrorCode.busy),
          okEnvelope({'id': 'row-1'}),
        ], requests: requests);

        runInvoke(async, () => invoke(client, requestId: 'req-99'));

        final ids = requests
            .map((r) => json.decode(r.body)['requestId'])
            .toList();
        expect(ids, ['req-99', 'req-99']);
      });
    });

    test('waits about a second before retrying', () {
      fakeAsync((async) {
        final requests = <http.Request>[];
        final client = buildClient([
          errorEnvelope(ScriptErrorCode.busy),
          okEnvelope({'id': 'row-1'}),
        ], requests: requests);

        unawaited(
          invoke(
            client,
          ).catchError((_) => const ScriptResult(id: '', replayed: false)),
        );

        async.elapse(const Duration(milliseconds: 999));
        expect(requests, hasLength(1), reason: 'retried too early');
        async.elapse(const Duration(milliseconds: 251));
        expect(requests, hasLength(2));
      });
    });

    test('gives up after the second attempt', () {
      fakeAsync((async) {
        final requests = <http.Request>[];
        final client = buildClient([
          errorEnvelope(ScriptErrorCode.busy),
          errorEnvelope(ScriptErrorCode.busy),
        ], requests: requests);

        final outcome = runInvoke(async, () => invoke(client));

        expect(
          outcome.error,
          isA<ScriptException>().having(
            (e) => e.code,
            'code',
            ScriptErrorCode.busy.code,
          ),
        );
        expect(requests, hasLength(2));
      });
    });

    test('does not retry any other error', () {
      fakeAsync((async) {
        final requests = <http.Request>[];
        final client = buildClient([
          errorEnvelope(ScriptErrorCode.forbidden),
        ], requests: requests);

        final outcome = runInvoke(async, () => invoke(client));

        expect(
          outcome.error,
          isA<ScriptException>().having(
            (e) => e.code,
            'code',
            ScriptErrorCode.forbidden.code,
          ),
        );
        expect(requests, hasLength(1));
      });
    });
  });

  group('timeout', () {
    /// A client that accepts the request and never answers.
    http.Client silentClient() =>
        MockClient((request) => Completer<http.Response>().future);

    test('gives up on a POST that never answers', () {
      fakeAsync((async) {
        final client = ScriptClient(
          url: url,
          token: token,
          httpClient: silentClient(),
        );

        final outcome = runInvoke(
          async,
          () => invoke(client),
          elapse: const Duration(seconds: 31),
        );

        expect(outcome.error, isA<TimeoutException>());
      });
    });

    test('stays above the lock timeout of the script', () {
      fakeAsync((async) {
        final client = ScriptClient(
          url: url,
          token: token,
          httpClient: silentClient(),
        );

        final outcome = runInvoke(
          async,
          () => invoke(client),
          // the script holds its lock for up to 20s
          elapse: const Duration(seconds: 25),
        );

        expect(outcome.error, isNull, reason: 'gave up while the script waits');
      });
    });

    test('gives up on a redirect that never answers', () {
      fakeAsync((async) {
        var first = true;
        final client = ScriptClient(
          url: url,
          token: token,
          httpClient: MockClient((request) {
            if (first) {
              first = false;
              return Future.value(redirectTo('/macros/s/DEPLOY_ID/echo'));
            }
            return Completer<http.Response>().future;
          }),
        );

        final outcome = runInvoke(
          async,
          () => invoke(client),
          elapse: const Duration(seconds: 31),
        );

        expect(outcome.error, isA<TimeoutException>());
      });
    });
  });
}
