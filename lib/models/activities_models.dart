/// Activity types. The code is used by the backend.
/// A type can be a task (i.e. can be marked as done) or not.
/// A type can also trigger an alert: it will be notified to all pilots (may be overridden in entry)
enum ActivityType {
  /// A simple note. Not a task.
  note(10, false, false),

  /// A minor task to be done (e.g. washing)
  minor(30, true, false),

  /// A non-critical issue requiring a notice to all pilots.
  notice(70, false, true),

  /// A relevant, important issue that must be addressed (although aircraft is able to fly).
  important(90, true, true),

  /// A critical issue, possibly related to flight security. Must be addressed before flight.
  critical(100, true, true);

  const ActivityType(this.code, this.task, this.alert);

  final int code;
  final bool task;
  final bool alert;

  static ActivityType fromCode(int code) =>
      ActivityType.values.firstWhere((element) => element.code == code);
}

enum ActivityStatus {
  todo('TODO'),
  inProgress('IN PROGRESS'),
  done('DONE');

  const ActivityStatus(this.label);

  final String label;

  static ActivityStatus fromLabel(String label) =>
      ActivityStatus.values.firstWhere((element) => element.label == label);
}

class ActivityEntry {
  ActivityEntry({
    this.id,
    required this.type,
    required this.creationDate,
    this.status,
    this.dueDate,
    required this.author,
    required this.summary,
    this.description,
    this.alert,
  });

  /// Entry ID. Used by the backend.
  String? id;

  /// Entry type.
  ActivityType type;

  /// Creation date.
  DateTime creationDate;

  /// Entry status.
  ActivityStatus? status;

  /// Due date (if any).
  DateTime? dueDate;

  /// Pilot that created this entry.
  String author;

  /// Entry summary.
  String summary;

  /// Entry description.
  String? description;

  /// Trigger an alert to all pilots. If null, the alert flag in [type] will be used.
  bool? alert;
}
