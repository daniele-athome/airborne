import 'package:intl/intl.dart';

import '../models/activities_models.dart';
import 'base_sheets_services.dart';

/// Due date formatter
final _kDateFormatter = DateFormat('yyyy-MM-dd');

/// A primitive way to abstract the real activities service.
class ActivitiesService extends RemoteStoreService<ActivityEntry> {
  ActivitiesService(super.client);

  @override
  String get storeName => 'activities';

  @override
  ActivityEntry buildItem(Map<String, dynamic> data) => ActivityEntry(
    id: data['id'] as String?,
    fingerprint: data['fingerprint'] as String?,
    creationDate: DateTime.parse(data['creationDate'] as String),
    type: ActivityType.fromCode(data['type'] as int),
    status: data['status'] != null
        ? ActivityStatus.fromLabel(data['status'] as String)
        : null,
    lastStatusUpdate: data['lastStatusUpdate'] != null
        ? DateTime.parse(data['lastStatusUpdate'] as String)
        : null,
    dueDate: data['dueDate'] != null
        ? DateTime.parse(data['dueDate'] as String)
        : null,
    author: data['author'] as String,
    summary: data['summary'] as String,
    description: data['description'] as String?,
    // TODO alert: ... (not really clear how to remember what we already alerted)
  );

  /// The creation date and the status timestamp are filled by the backend: the
  /// latter is stamped only when the status actually changes.
  @override
  Map<String, dynamic> buildPayload(ActivityEntry item) => {
    'type': item.type.code,
    'status': item.status?.label,
    'dueDate': item.dueDate != null
        ? _kDateFormatter.format(item.dueDate!)
        : null,
    'author': item.author,
    'summary': item.summary,
    'description': item.description,
  };

  @override
  String? fingerprintOf(ActivityEntry item) => item.fingerprint;

  @override
  String? idOf(ActivityEntry item) => item.id;
}
