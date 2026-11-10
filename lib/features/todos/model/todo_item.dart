var _todoIdSeed = 0;

String newTodoId() {
  _todoIdSeed += 1;
  return 'todo_${DateTime.now().microsecondsSinceEpoch}_$_todoIdSeed';
}

class TodoItem {
  const TodoItem({
    required this.id,
    required this.title,
    this.note = '',
    required this.dueAt,
    this.source = '',
    this.completed = false,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String note;
  final DateTime dueAt;
  final String source;
  final bool completed;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool isOverdueAt(DateTime now) {
    return !completed && dueAt.isBefore(now);
  }

  TodoItem copyWith({
    String? id,
    String? title,
    String? note,
    DateTime? dueAt,
    String? source,
    bool? completed,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TodoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      dueAt: dueAt ?? this.dueAt,
      source: source ?? this.source,
      completed: completed ?? this.completed,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'note': note,
      'dueAt': dueAt.toIso8601String(),
      'source': source,
      'completed': completed,
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TodoItem.fromJson(Map<String, Object?> json) {
    final dueAt = DateTime.tryParse(json['dueAt']?.toString() ?? '');
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    final updatedAt = DateTime.tryParse(json['updatedAt']?.toString() ?? '');
    return TodoItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      dueAt: dueAt ?? DateTime.now(),
      source: json['source']?.toString() ?? '',
      completed: json['completed'] == true,
      completedAt: DateTime.tryParse(json['completedAt']?.toString() ?? ''),
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
