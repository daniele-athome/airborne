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
/// with the app version. The contract is described in `server/openapi.yaml`.
const kProtocolVersion = 1;

/// The operations the backend script exposes.
///
/// All three change data, which is why every one of them needs a request id.
/// There is no read action: the app reads the flight log straight from Google
/// Sheets with its own credentials.
abstract class ScriptAction {
  static const flightLogInsert = 'flight-log/insert';
  static const flightLogUpdate = 'flight-log/update';
  static const flightLogDelete = 'flight-log/delete';
}

/// Error codes returned by the backend script.
///
/// Unknown codes must not break the client: the app falls back to a generic
/// message, which is what lets the script add codes without a version bump.
abstract class ScriptErrorCode {
  static const badRequest = 'BAD_REQUEST';
  static const unauthorized = 'UNAUTHORIZED';
  static const forbidden = 'FORBIDDEN';
  static const notFound = 'NOT_FOUND';
  static const busy = 'BUSY';
  static const protocolIncompatible = 'PROTOCOL_INCOMPATIBLE';
  static const internal = 'INTERNAL';

  /// Not a code the script returns: the response was not JSON at all, which
  /// means the request never reached the script.
  static const notReachable = 'NOT_REACHABLE';

  /// Not a code the script returns: the script answered, and the answer did not
  /// look like the protocol. Whether the write landed is unknown.
  static const malformedResponse = 'MALFORMED_RESPONSE';
}

/// An error reported by the backend script, or by this client on its behalf.
class ScriptException implements Exception {
  const ScriptException(
    this.code,
    this.message, {
    this.details,
    this.vMin,
    this.vMax,
  });

  /// One of [ScriptErrorCode], but not necessarily: a newer script may answer
  /// with a code this build has never heard of, and that must not crash it.
  final String code;

  /// Diagnostic, in English, and not stable across releases. Localize from
  /// [code]; show this only as the fallback for a code you do not know.
  final String message;

  /// Server-side stack trace, on [ScriptErrorCode.internal] only. For the log,
  /// never for a pilot.
  final String? details;

  /// Oldest protocol version the deployment accepts, when it said so. Only
  /// meaningful on [ScriptErrorCode.protocolIncompatible].
  final int? vMin;

  /// Newest protocol version the deployment accepts, when it said so.
  final int? vMax;

  /// Whether the app is too old for the deployment, rather than too new.
  bool get isAppTooOld =>
      code == ScriptErrorCode.protocolIncompatible &&
      vMin != null &&
      kProtocolVersion < vMin!;

  @override
  String toString() => 'ScriptException{code: $code, message: $message}';
}

/// The entry an action acted on.
class ScriptResult {
  const ScriptResult({required this.id, required this.replayed});

  /// Stable id of the entry. On an insert this is the only time the app is told
  /// it: an entry whose id was never received can never be edited afterwards.
  final String id;

  /// True when the script replayed a stored answer instead of running the
  /// operation, because an earlier request carried the same request id. The
  /// outcome is the same; only the fact that nothing ran a second time differs.
  final bool replayed;

  @override
  String toString() => 'ScriptResult{id: $id, replayed: $replayed}';
}

/// Talks to the Apps Script web app that owns the spreadsheet.
///
/// Three things about this backend shape the whole class:
///
/// * **The status code says nothing.** Apps Script cannot set one, so anything
///   the script manages to run answers 200 — success and failure alike. The
///   outcome is read out of the body, and failures surface as [ScriptException]
///   built from `error.code`.
/// * **The answer is one redirect away.** A POST to `/exec` returns a 302 and
///   the body is served by the request that follows it. That hop is handled
///   here rather than left to the HTTP client, for the reason explained on
///   [_send].
/// * **The token travels in the body**, so it never lands in a URL where it
///   could be logged by an intermediary.
///
/// Note for a web build: the request is `application/json`, which is not a
/// CORS-safelisted content type, and Apps Script does not answer the preflight
/// it triggers. This client works from mobile and desktop, not from a browser.
class ScriptClient {
  ScriptClient({
    required String url,
    required String token,
    http.Client? httpClient,
  }) : _url = Uri.parse(url),
       _token = token,
       _httpClient = httpClient ?? http.Client();

  /// Must stay above the script's own lock timeout of 20s, or the client would
  /// give up while the server is still legitimately waiting its turn to write.
  static const _timeout = Duration(seconds: 30);

  /// How many times a BUSY response is retried before giving up.
  static const _maxBusyAttempts = 4;

  /// Redirect hops allowed. Apps Script always uses one.
  static const _maxRedirects = 5;

  /// Identifies this build in the log of the deployment. Diagnostic only:
  /// nothing is decided on its value.
  static final _clientId = '${Pubspec.name}/${Pubspec.version.canonical}';

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
  /// Generate it once per user intent and reuse it across retries: a fresh key
  /// per attempt would let a retried write be applied twice. This is why the
  /// three methods below take it instead of making one up — only the caller
  /// knows where one intent ends and the next begins.
  String newRequestId() {
    final buffer = StringBuffer(
      DateTime.now().microsecondsSinceEpoch.toRadixString(16),
    );
    for (var i = 0; i < 4; i++) {
      buffer.write(_random.nextInt(0x100000000).toRadixString(16));
    }
    return buffer.toString();
  }

  /// Files a new flight and returns the id assigned to it.
  ///
  /// [flight] carries the schema fields: `date`, `startHour`, `endHour`,
  /// `origin` and `destination` are required, `fuel`, `fuelPrice` and `notes`
  /// are optional. `pilotName` may be omitted to file the flight under the
  /// authenticated pilot, which is what an ordinary client does.
  Future<ScriptResult> insertFlight({
    required String requestId,
    required Map<String, dynamic> flight,
  }) => _invoke(
    action: ScriptAction.flightLogInsert,
    requestId: requestId,
    payload: flight,
  );

  /// Changes an existing flight.
  ///
  /// Only the fields present in [changes] are touched: the script rewrites the
  /// whole row, reading everything else back out of the sheet, so leaving a
  /// field out keeps it rather than clearing it. A required field cannot be
  /// blanked — sending an empty string for one is a `BAD_REQUEST`.
  Future<ScriptResult> updateFlight({
    required String requestId,
    required String id,
    required Map<String, dynamic> changes,
  }) => _invoke(
    action: ScriptAction.flightLogUpdate,
    requestId: requestId,
    // The explicit id wins over anything the caller left in the map.
    payload: {...changes, 'id': id},
  );

  /// Removes a flight.
  Future<ScriptResult> deleteFlight({
    required String requestId,
    required String id,
  }) => _invoke(
    action: ScriptAction.flightLogDelete,
    requestId: requestId,
    payload: {'id': id},
  );

  /// Sends one envelope, retrying while the script reports itself busy.
  ///
  /// The envelope also has an `expect` field, for preconditions to be checked
  /// under the lock. The current script parses it and does nothing with it, so
  /// there is nothing here to fill it with yet.
  Future<ScriptResult> _invoke({
    required String action,
    required String requestId,
    required Map<String, dynamic> payload,
  }) async {
    final body = <String, dynamic>{
      'v': kProtocolVersion,
      'token': _token,
      'action': action,
      'requestId': requestId,
      'client': _clientId,
      'payload': payload,
    };

    var attempt = 0;
    while (true) {
      attempt++;
      try {
        return _unwrap(await _send(body));
      } on ScriptException catch (e) {
        if (e.code != ScriptErrorCode.busy || attempt >= _maxBusyAttempts) {
          rethrow;
        }
        // Another write holds the lock, and BUSY means nothing ran. The request
        // id is kept, so even if this assumption were wrong the retry would
        // replay the stored answer instead of applying the change twice.
        final backoff = 1000 + _random.nextInt(250);
        _log.fine('backend busy, retry $attempt in ${backoff}ms');
        await Future.delayed(Duration(milliseconds: backoff));
      }
    }
  }

  /// Posts the envelope, following the redirect Apps Script answers with.
  ///
  /// The redirect is handled here rather than left to the HTTP client because
  /// clients disagree on what to do with a 302 on a POST: `curl` turns it into
  /// a GET, while `dart:io` follows RFC 9110 to the letter and repeats the
  /// POST, body and all. Apps Script has already computed the answer by the
  /// time it redirects, so the hop must be a plain GET — pinning it here means
  /// the behaviour does not depend on which HTTP stack the platform provides.
  Future<http.Response> _send(Map<String, dynamic> body) async {
    var target = _url;
    var response = await _httpClient
        .send(_buildRequest(target, body))
        .then(http.Response.fromStream)
        .timeout(_timeout);

    var hops = 0;
    while (response.isRedirect && hops < _maxRedirects) {
      final location = response.headers['location'];
      if (location == null) {
        break;
      }
      // Apps Script sends an absolute URL on another host; resolving against
      // the current target keeps a relative one working too.
      target = target.resolve(location);
      hops++;
      response = await _httpClient.get(target).timeout(_timeout);
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

  /// Turns a raw response into a [ScriptResult] or a [ScriptException].
  ScriptResult _unwrap(http.Response response) {
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

    if (decoded['ok'] != true) {
      final error = decoded['error'] as Map<String, dynamic>?;
      throw ScriptException(
        error?['code'] as String? ?? ScriptErrorCode.internal,
        error?['message'] as String? ?? 'Unknown backend error',
        details: error?['details'] as String?,
        vMin: decoded['vMin'] as int?,
        vMax: decoded['vMax'] as int?,
      );
    }

    final data = decoded['data'];
    final id = data is Map<String, dynamic> ? data['id'] : null;
    if (id is! String || id.isEmpty) {
      // The operation reported success, so it did happen; the app just cannot
      // tell which entry it happened to. Retrying with the same request id is
      // safe and would replay the same answer, so it would not help.
      _log.severe('backend reported success without an entry id: $data');
      throw const ScriptException(
        ScriptErrorCode.malformedResponse,
        'The backend reported success without naming the entry.',
      );
    }

    return ScriptResult(id: id, replayed: decoded['replayed'] == true);
  }
}
