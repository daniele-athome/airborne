import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../pubspec.yaml.g.dart';

final Logger _log = Logger((ScriptClient).toString());

/// Protocol contract version spoken by this build.
///
/// It moves only on breaking changes to the request or response shapes, not
/// with the app version. See `server/README.md`.
const kProtocolVersion = 1;

/// Error codes returned by the backend script.
///
/// Unknown codes must not break the client: the app falls back to a generic
/// message, which is what lets the script add codes without a version bump.
abstract class ScriptErrorCode {
  static const badRequest = 'BAD_REQUEST';
  static const unauthorized = 'UNAUTHORIZED';
  static const forbidden = 'FORBIDDEN';
  static const notFound = 'NOT_FOUND';
  static const conflict = 'CONFLICT';
  static const busy = 'BUSY';
  static const protocolTooOld = 'PROTOCOL_TOO_OLD';
  static const protocolTooNew = 'PROTOCOL_TOO_NEW';
  static const internal = 'INTERNAL';

  /// Not a code the script returns: the response was not JSON at all, which
  /// means the request never reached the script.
  static const notReachable = 'NOT_REACHABLE';
}

/// An error reported by the backend script.
class ScriptException implements Exception {
  const ScriptException(this.code, this.message, [this.details]);

  final String code;
  final String message;
  final Map<String, dynamic>? details;

  @override
  String toString() => 'ScriptException{code: $code, message: $message}';
}

/// The outcome of a successful call.
class ScriptResponse {
  const ScriptResponse(this.data, this.state);

  /// Action-specific payload.
  final Map<String, dynamic>? data;

  /// Version and row count of every store the action touched, keyed by store.
  final Map<String, dynamic> state;

  /// Version of [store] as of this response, or null if it was not reported.
  String? hashOf(String store) =>
      (state[store] as Map<String, dynamic>?)?['hash'] as String?;

  /// Row count of [store] as of this response, or null.
  int? countOf(String store) =>
      (state[store] as Map<String, dynamic>?)?['count'] as int?;
}

/// Talks to the Apps Script web app that owns the spreadsheet.
///
/// Everything travels in the request body, so the token never appears in a URL
/// where it could be logged. The script always answers 200 for anything it
/// manages to run, so failures arrive as [ScriptException] built from the
/// `error.code` in the body rather than from a status code.
class ScriptClient {
  ScriptClient({
    required String url,
    required String token,
    http.Client? httpClient,
  }) : _url = Uri.parse(url),
       _token = token,
       _httpClient = httpClient ?? http.Client();

  static const _timeout = Duration(seconds: 30);

  /// How many times a BUSY response is retried before giving up.
  static const _maxBusyAttempts = 4;

  /// Redirect hops allowed. Apps Script always uses one.
  static const _maxRedirects = 5;

  final Uri _url;
  final String _token;
  http.Client _httpClient;

  final Random _random = Random();

  @visibleForTesting
  set httpClient(http.Client client) {
    _httpClient = client;
  }

  /// Builds an idempotency key.
  ///
  /// Callers must generate it once per user intent and reuse it across retries:
  /// a fresh key per attempt would let a retried write be applied twice.
  String newRequestId() {
    final buffer = StringBuffer(
      DateTime.now().microsecondsSinceEpoch.toRadixString(16),
    );
    for (var i = 0; i < 4; i++) {
      buffer.write(_random.nextInt(0x100000000).toRadixString(16));
    }
    return buffer.toString();
  }

  Future<ScriptResponse> invoke({
    required String action,
    String? store,
    Map<String, dynamic>? payload,
    Map<String, dynamic>? expect,
    String? requestId,
    bool force = false,
  }) async {
    final body = <String, dynamic>{
      'v': kProtocolVersion,
      'token': _token,
      'action': action,
      'client': Pubspec.version.representation,
      'store': ?store,
      'payload': ?payload,
      'expect': ?expect,
      'requestId': ?requestId,
      if (force) 'force': true,
    };

    var attempt = 0;
    while (true) {
      attempt++;
      try {
        return _unwrap(await _post(body));
      } on ScriptException catch (e) {
        if (e.code != ScriptErrorCode.busy || attempt >= _maxBusyAttempts) {
          rethrow;
        }
        // Another write holds the lock. The request id is kept, so if the
        // previous attempt did land, the retry replays its result instead of
        // applying the change twice.
        final hint = e.details?['retryAfterMs'];
        final backoff = hint is int ? hint : 1000;
        final jitter = _random.nextInt(250);
        _log.fine('backend busy, retry $attempt in ${backoff + jitter}ms');
        await Future.delayed(Duration(milliseconds: backoff + jitter));
      }
    }
  }

  /// Posts the envelope, following the redirect Apps Script answers with.
  ///
  /// The redirect is handled here rather than left to the HTTP client because
  /// clients disagree on what to do with a 302 on a POST — some replay the
  /// body, some drop it. Apps Script has already computed the response by the
  /// time it redirects, so the hop is a plain GET.
  Future<http.Response> _post(Map<String, dynamic> body) async {
    var response = await _httpClient
        .send(_buildRequest(_url, body))
        .then(http.Response.fromStream)
        .timeout(_timeout);

    var hops = 0;
    while (response.isRedirect && hops < _maxRedirects) {
      final location = response.headers['location'];
      if (location == null) {
        break;
      }
      hops++;
      response = await _httpClient
          .get(_url.resolve(location))
          .timeout(_timeout);
    }

    return response;
  }

  http.Request _buildRequest(Uri url, Map<String, dynamic> body) {
    final request = http.Request('POST', url)
      ..followRedirects = false
      ..headers['content-type'] = 'application/json; charset=utf-8'
      ..body = json.encode(body);
    return request;
  }

  /// Turns a raw response into a [ScriptResponse] or a [ScriptException].
  ScriptResponse _unwrap(http.Response response) {
    final Map<String, dynamic> decoded;
    try {
      decoded = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      // Almost always a deployment whose access setting sends callers to a
      // login page: worth its own code, because the fix is in the Google
      // console and not in the app.
      _log.warning(
        'backend answered ${response.statusCode} with non-JSON content',
      );
      throw const ScriptException(
        ScriptErrorCode.notReachable,
        'The backend did not answer with JSON. '
        'Check the web app deployment and its access settings.',
      );
    }

    if (decoded['ok'] == true) {
      return ScriptResponse(
        decoded['data'] as Map<String, dynamic>?,
        (decoded['state'] as Map<String, dynamic>?) ?? const {},
      );
    }

    final error = decoded['error'] as Map<String, dynamic>?;
    throw ScriptException(
      error?['code'] as String? ?? ScriptErrorCode.internal,
      error?['message'] as String? ?? 'Unknown backend error',
      error?['details'] as Map<String, dynamic>?,
    );
  }
}
