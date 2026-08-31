import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../pubspec.yaml.g.dart';

final Logger _log = Logger((ScriptClient).toString());

/// The version of the server-side protocol we support.
const kProtocolVersion = 1;

enum ScriptAction {
  flightLogInsert('flight-log/insert'),
  flightLogUpdate('flight-log/update'),
  flightLogDelete('flight-log/delete');

  const ScriptAction(this.action);

  final String action;
}

enum ScriptErrorCode implements Comparable<ScriptErrorCode> {
  badRequest('BAD_REQUEST'),
  unauthorized('UNAUTHORIZED'),
  forbidden('FORBIDDEN'),
  notFound('NOT_FOUND'),
  busy('BUSY'),
  protocolIncompatible('PROTOCOL_INCOMPATIBLE'),
  internal('INTERNAL'),

  /// Not a code the script returns: the response was not JSON at all, which
  /// means the request never reached the script.
  notReachable('NOT_REACHABLE'),

  /// Not a code the script returns: the script answered, and the answer did not
  /// look like the protocol. Whether the write landed is unknown.
  malformedResponse('MALFORMED_RESPONSE');

  const ScriptErrorCode(this.code);

  /// The value as it appears on the wire.
  final String code;

  /// Whether this code was produced by the script itself, as opposed to being
  /// synthesized locally when the response could not be interpreted.
  bool get isFromScript => this != notReachable && this != malformedResponse;

  /// Parses a code coming from the script. An unrecognized value is itself a
  /// protocol violation, hence [malformedResponse].
  static ScriptErrorCode fromCode(String value) => values.firstWhere(
    (c) => c.code == value,
    orElse: () => malformedResponse,
  );

  @override
  int compareTo(ScriptErrorCode other) {
    return code.compareTo(other.code);
  }
}

/// An error reported by the backend script, or by this client on its behalf.
class ScriptException implements Exception {
  const ScriptException(this.code, this.message, {this.details});

  /// One of [ScriptErrorCode]; it's a string because we might have other, yet
  /// unknown values.
  final String code;

  /// An error message.
  final String message;

  /// Error details (might include a stacktrace).
  final String? details;

  @override
  String toString() => 'ScriptException{code: $code, message: $message}';
}

/// The entry an action acted on.
class ScriptResult {
  const ScriptResult({required this.id, required this.replayed});

  /// Stable id of the entry.
  final String id;

  /// True when the idempotency check kicked in.
  final bool replayed;

  @override
  String toString() => 'ScriptResult{id: $id, replayed: $replayed}';
}

/// A client for the Apps Script deployed web app.
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
  static const _maxBusyAttempts = 2;

  /// Identifies this build in the log of the deployment. Diagnostic only:
  /// nothing is decided on its value.
  static final _clientId = '${Pubspec.name}/${Pubspec.version.canonical}';

  final Uri _url;
  final String _token;
  final http.Client _httpClient;

  static final Random _random = Random();

  /// Utility method for building an idempotency key.
  static String newRequestId() {
    final buffer = StringBuffer(
      DateTime.now().microsecondsSinceEpoch.toRadixString(16),
    );
    for (var i = 0; i < 4; i++) {
      buffer.write(_random.nextInt(0x100000000).toRadixString(16));
    }
    return buffer.toString();
  }

  /// Files a new flight and returns the id assigned to it.
  Future<ScriptResult> insertFlight({
    required String requestId,
    required Map<String, dynamic> flight,
  }) => _invoke(
    action: ScriptAction.flightLogInsert,
    requestId: requestId,
    payload: flight,
  );

  /// Changes an existing flight. Only the passed fields will be updated.
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
  Future<ScriptResult> _invoke({
    required ScriptAction action,
    required String requestId,
    required Map<String, dynamic> payload,
  }) async {
    final body = <String, dynamic>{
      'v': kProtocolVersion,
      'token': _token,
      'action': action.action,
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
        if (e.code != ScriptErrorCode.busy.code ||
            attempt >= _maxBusyAttempts) {
          rethrow;
        }
        final backoff = 1000 + _random.nextInt(250);
        _log.fine('backend busy, retry $attempt in ${backoff}ms');
        await Future.delayed(Duration(milliseconds: backoff));
      }
    }
  }

  /// Posts the envelope, following the redirect Apps Script answers with.
  Future<http.Response> _send(Map<String, dynamic> body) async {
    var target = _url;
    var response = await _httpClient
        .send(_buildRequest(target, body))
        .then(http.Response.fromStream)
        .timeout(_timeout);

    final location = response.headers['location'];
    if (location == null) {
      // return the response from the POST call - although it'll be useless
      return response;
    }

    // the redirect would be on another host - the resolve call will work anyway
    target = target.resolve(location);
    return await _httpClient.get(target).timeout(_timeout);
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
      _log.warning(
        'backend answered ${response.statusCode} with non-JSON content',
      );
      throw ScriptException(
        ScriptErrorCode.notReachable.code,
        'The backend did not answer with JSON. '
        'Check the web app deployment and its access settings.',
      );
    }

    if (decoded['ok'] != true) {
      final error = decoded['error'] as Map<String, dynamic>?;
      throw ScriptException(
        error?['code'] as String? ?? ScriptErrorCode.internal.code,
        error?['message'] as String? ?? 'Unknown backend error',
        details: error?['details'] as String?,
      );
    }

    final data = decoded['data'];
    final id = data is Map<String, dynamic> ? data['id'] : null;
    if (id is! String || id.isEmpty) {
      _log.severe('backend reported success without an entry id: $data');
      throw ScriptException(
        ScriptErrorCode.malformedResponse.code,
        'The backend reported success without naming the entry.',
      );
    }

    return ScriptResult(id: id, replayed: decoded['replayed'] == true);
  }
}
