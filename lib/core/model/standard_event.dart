enum EventType {
  assignment('assignment'),
  course('course'),
  onlineSession('online_session');

  const EventType(this.wireName);

  final String wireName;

  static EventType parse(String? raw) {
    for (final value in EventType.values) {
      if (value.wireName == raw || value.name == raw) {
        return value;
      }
    }
    return EventType.assignment;
  }
}

class StandardEvent {
  const StandardEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.source,
    this.dueTime,
  });

  factory StandardEvent.fromJson(Map<String, Object?> json) {
    final dueTime = json['dueTime'];

    return StandardEvent(
      id: json['id']! as String,
      type: EventType.parse(json['type'] as String?),
      title: json['title']! as String,
      source: json['source']! as String,
      dueTime: dueTime is String ? DateTime.tryParse(dueTime) : null,
    );
  }

  final String id;
  final EventType type;
  final String title;
  final DateTime? dueTime;
  final String source;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'type': type.wireName,
      'title': title,
      'source': source,
      'dueTime': dueTime?.toIso8601String(),
    };
  }
}
