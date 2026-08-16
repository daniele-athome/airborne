import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'script_client.dart';

/// Items per page to fetch.
const _kItemsPerPage = 20;

/// A base class for a data store served by the backend script.
///
/// The data still lives in a Google Sheet, but the app no longer reads or
/// writes it directly: the script owns the sheet and performs check-and-write
/// inside a single locked execution. Two consequences shape this class.
///
/// There is no version polling any more. The store version travels back in the
/// response of the write that caused it, so a write completes when its request
/// completes.
///
/// Item ids and fingerprints are opaque values assigned by the server. The app
/// never derives an id from a row position — the sheet is re-sorted on every
/// change, so a position identifies nothing for long.
///
/// `<T>` is the type of the data object represented in the store.
abstract class RemoteStoreService<T> {
  late final Logger _log = Logger(runtimeType.toString());

  ScriptClient _client;

  /// Opaque cursor of the next page, or null when at the beginning.
  String? _cursor;

  /// Whether [fetchItems] can still return something.
  bool _hasMore = true;

  /// Store version as of the last response.
  String? _hash;

  /// Number of items as of the last response.
  int _count = 0;

  RemoteStoreService(this._client);

  @visibleForTesting
  set client(ScriptClient client) {
    _client = client;
  }

  /// Store name as known by the backend.
  String get storeName;

  /// Builds a data object from the item map returned by the backend.
  T buildItem(Map<String, dynamic> data);

  /// Builds the field map to send for [item]. Server-managed fields are omitted.
  Map<String, dynamic> buildPayload(T item);

  /// The precondition token [item] was last seen with.
  String? fingerprintOf(T item);

  /// The backend id of [item].
  String? idOf(T item);

  /// Store version as of the last response, mostly useful for diagnostics.
  String? get dataHash => _hash;

  /// Number of items as of the last response.
  int get itemCount => _count;

  /// Restarts pagination from the most recent item.
  ///
  /// Deliberately does not talk to the network: the first [fetchItems] brings
  /// back the state along with the data.
  Future<void> reset() async {
    _cursor = null;
    _hasMore = true;
  }

  bool hasMoreData() => _hasMore;

  Future<Iterable<T>> fetchItems() async {
    final response = await _client.invoke(
      action: 'list',
      store: storeName,
      payload: {
        'pageSize': _kItemsPerPage,
        if (_cursor != null) 'cursor': _cursor,
      },
    );
    _absorbState(response);

    final data = response.data ?? const <String, dynamic>{};
    _cursor = data['nextCursor'] as String?;
    _hasMore = data['hasMore'] == true;

    if (data['stale'] == true) {
      // The store moved while we were paging. The page is still served, so this
      // is worth a log rather than an error in the user's face.
      _log.info('$storeName changed while paging');
    }

    final items = data['items'] as List<dynamic>? ?? const [];
    _log.finest('fetched ${items.length} items, hasMore=$_hasMore');
    return items.map((e) => buildItem(e as Map<String, dynamic>));
  }

  Future<T> appendItem(T item) async {
    // No precondition: an append cannot conflict with another append, and
    // requiring one would fail every time somebody else wrote while this form
    // was open.
    final response = await _mutate(
      action: 'insert',
      payload: buildPayload(item),
    );
    return buildItem(response.data!);
  }

  Future<T> updateItem(String id, T item) async {
    final response = await _mutate(
      action: 'update',
      payload: {...buildPayload(item), 'id': id},
      expect: _expectationFor(item),
    );
    return buildItem(response.data!);
  }

  Future<String?> deleteItem(T item) async {
    final id = idOf(item);
    if (id == null) {
      throw ArgumentError('Cannot delete an item without an id');
    }
    await _mutate(
      action: 'delete',
      payload: {'id': id},
      expect: _expectationFor(item),
    );
    return id;
  }

  /// Builds the concurrency precondition to send with a write.
  ///
  /// The per-item fingerprint is preferred because it only conflicts when that
  /// very item changed. The store version is the fallback for an item that
  /// somehow arrived without one: coarser, but better than writing blind.
  Map<String, dynamic> _expectationFor(T item) {
    final fingerprint = fingerprintOf(item);
    if (fingerprint != null) {
      return {'fingerprint': fingerprint};
    }
    return {'hash': _hash};
  }

  Future<ScriptResponse> _mutate({
    required String action,
    required Map<String, dynamic> payload,
    Map<String, dynamic>? expect,
  }) async {
    // Generated once per user action: the retries that matter happen inside the
    // client, and they all carry this same id so a write that already landed is
    // replayed instead of applied twice.
    final requestId = _client.newRequestId();
    try {
      final response = await _client.invoke(
        action: action,
        store: storeName,
        payload: payload,
        expect: expect,
        requestId: requestId,
      );
      _absorbState(response);
      return response;
    } on ScriptException catch (e) {
      // NOT_FOUND is reported as a change too: from the user's point of view
      // "somebody deleted this while you were editing" is the same story as
      // "somebody modified it", and it already has a message.
      if (e.code == ScriptErrorCode.conflict ||
          e.code == ScriptErrorCode.notFound) {
        throw DataChangedException(
          e.details?['current'] as Map<String, dynamic>?,
        );
      }
      rethrow;
    }
  }

  void _absorbState(ScriptResponse response) {
    _hash = response.hashOf(storeName) ?? _hash;
    _count = response.countOf(storeName) ?? _count;
  }
}

/// Exception thrown when the item was modified or removed by someone else.
class DataChangedException implements Exception {
  const DataChangedException([this.current]);

  /// The item as it is now, when the backend could report it.
  final Map<String, dynamic>? current;

  @override
  String toString() => 'DataChangedException{current: $current}';
}
