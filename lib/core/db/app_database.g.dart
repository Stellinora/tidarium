// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $StandardEventsTable extends StandardEvents
    with TableInfo<$StandardEventsTable, StandardEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StandardEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueTimeMeta = const VerificationMeta(
    'dueTime',
  );
  @override
  late final GeneratedColumn<int> dueTime = GeneratedColumn<int>(
    'due_time',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawJsonMeta = const VerificationMeta(
    'rawJson',
  );
  @override
  late final GeneratedColumn<String> rawJson = GeneratedColumn<String>(
    'raw_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<int> fetchedAt = GeneratedColumn<int>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    title,
    dueTime,
    source,
    rawJson,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'standard_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<StandardEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('due_time')) {
      context.handle(
        _dueTimeMeta,
        dueTime.isAcceptableOrUnknown(data['due_time']!, _dueTimeMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('raw_json')) {
      context.handle(
        _rawJsonMeta,
        rawJson.isAcceptableOrUnknown(data['raw_json']!, _rawJsonMeta),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StandardEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StandardEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      dueTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_time'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      rawJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_json'],
      ),
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $StandardEventsTable createAlias(String alias) {
    return $StandardEventsTable(attachedDatabase, alias);
  }
}

class StandardEventRow extends DataClass
    implements Insertable<StandardEventRow> {
  final String id;
  final String type;
  final String title;
  final int? dueTime;
  final String source;
  final String? rawJson;
  final int fetchedAt;
  const StandardEventRow({
    required this.id,
    required this.type,
    required this.title,
    this.dueTime,
    required this.source,
    this.rawJson,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || dueTime != null) {
      map['due_time'] = Variable<int>(dueTime);
    }
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || rawJson != null) {
      map['raw_json'] = Variable<String>(rawJson);
    }
    map['fetched_at'] = Variable<int>(fetchedAt);
    return map;
  }

  StandardEventsCompanion toCompanion(bool nullToAbsent) {
    return StandardEventsCompanion(
      id: Value(id),
      type: Value(type),
      title: Value(title),
      dueTime: dueTime == null && nullToAbsent
          ? const Value.absent()
          : Value(dueTime),
      source: Value(source),
      rawJson: rawJson == null && nullToAbsent
          ? const Value.absent()
          : Value(rawJson),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory StandardEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StandardEventRow(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      title: serializer.fromJson<String>(json['title']),
      dueTime: serializer.fromJson<int?>(json['dueTime']),
      source: serializer.fromJson<String>(json['source']),
      rawJson: serializer.fromJson<String?>(json['rawJson']),
      fetchedAt: serializer.fromJson<int>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'title': serializer.toJson<String>(title),
      'dueTime': serializer.toJson<int?>(dueTime),
      'source': serializer.toJson<String>(source),
      'rawJson': serializer.toJson<String?>(rawJson),
      'fetchedAt': serializer.toJson<int>(fetchedAt),
    };
  }

  StandardEventRow copyWith({
    String? id,
    String? type,
    String? title,
    Value<int?> dueTime = const Value.absent(),
    String? source,
    Value<String?> rawJson = const Value.absent(),
    int? fetchedAt,
  }) => StandardEventRow(
    id: id ?? this.id,
    type: type ?? this.type,
    title: title ?? this.title,
    dueTime: dueTime.present ? dueTime.value : this.dueTime,
    source: source ?? this.source,
    rawJson: rawJson.present ? rawJson.value : this.rawJson,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  StandardEventRow copyWithCompanion(StandardEventsCompanion data) {
    return StandardEventRow(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      dueTime: data.dueTime.present ? data.dueTime.value : this.dueTime,
      source: data.source.present ? data.source.value : this.source,
      rawJson: data.rawJson.present ? data.rawJson.value : this.rawJson,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StandardEventRow(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('dueTime: $dueTime, ')
          ..write('source: $source, ')
          ..write('rawJson: $rawJson, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, type, title, dueTime, source, rawJson, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StandardEventRow &&
          other.id == this.id &&
          other.type == this.type &&
          other.title == this.title &&
          other.dueTime == this.dueTime &&
          other.source == this.source &&
          other.rawJson == this.rawJson &&
          other.fetchedAt == this.fetchedAt);
}

class StandardEventsCompanion extends UpdateCompanion<StandardEventRow> {
  final Value<String> id;
  final Value<String> type;
  final Value<String> title;
  final Value<int?> dueTime;
  final Value<String> source;
  final Value<String?> rawJson;
  final Value<int> fetchedAt;
  final Value<int> rowid;
  const StandardEventsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.dueTime = const Value.absent(),
    this.source = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StandardEventsCompanion.insert({
    required String id,
    required String type,
    required String title,
    this.dueTime = const Value.absent(),
    required String source,
    this.rawJson = const Value.absent(),
    required int fetchedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       title = Value(title),
       source = Value(source),
       fetchedAt = Value(fetchedAt);
  static Insertable<StandardEventRow> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? title,
    Expression<int>? dueTime,
    Expression<String>? source,
    Expression<String>? rawJson,
    Expression<int>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (dueTime != null) 'due_time': dueTime,
      if (source != null) 'source': source,
      if (rawJson != null) 'raw_json': rawJson,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StandardEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String>? title,
    Value<int?>? dueTime,
    Value<String>? source,
    Value<String?>? rawJson,
    Value<int>? fetchedAt,
    Value<int>? rowid,
  }) {
    return StandardEventsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      dueTime: dueTime ?? this.dueTime,
      source: source ?? this.source,
      rawJson: rawJson ?? this.rawJson,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (dueTime.present) {
      map['due_time'] = Variable<int>(dueTime.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (rawJson.present) {
      map['raw_json'] = Variable<String>(rawJson.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<int>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StandardEventsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('dueTime: $dueTime, ')
          ..write('source: $source, ')
          ..write('rawJson: $rawJson, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TodosTable extends Todos with TableInfo<$TodosTable, TodoRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<int> dueAt = GeneratedColumn<int>(
    'due_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    note,
    dueAt,
    source,
    completed,
    completedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todos';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    } else if (isInserting) {
      context.missing(_dueAtMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TodoRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_at'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TodosTable createAlias(String alias) {
    return $TodosTable(attachedDatabase, alias);
  }
}

class TodoRow extends DataClass implements Insertable<TodoRow> {
  final String id;
  final String title;
  final String note;
  final int dueAt;
  final String source;
  final bool completed;
  final int? completedAt;
  final int createdAt;
  final int updatedAt;
  const TodoRow({
    required this.id,
    required this.title,
    required this.note,
    required this.dueAt,
    required this.source,
    required this.completed,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['note'] = Variable<String>(note);
    map['due_at'] = Variable<int>(dueAt);
    map['source'] = Variable<String>(source);
    map['completed'] = Variable<bool>(completed);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<int>(completedAt);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  TodosCompanion toCompanion(bool nullToAbsent) {
    return TodosCompanion(
      id: Value(id),
      title: Value(title),
      note: Value(note),
      dueAt: Value(dueAt),
      source: Value(source),
      completed: Value(completed),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TodoRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      note: serializer.fromJson<String>(json['note']),
      dueAt: serializer.fromJson<int>(json['dueAt']),
      source: serializer.fromJson<String>(json['source']),
      completed: serializer.fromJson<bool>(json['completed']),
      completedAt: serializer.fromJson<int?>(json['completedAt']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'note': serializer.toJson<String>(note),
      'dueAt': serializer.toJson<int>(dueAt),
      'source': serializer.toJson<String>(source),
      'completed': serializer.toJson<bool>(completed),
      'completedAt': serializer.toJson<int?>(completedAt),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  TodoRow copyWith({
    String? id,
    String? title,
    String? note,
    int? dueAt,
    String? source,
    bool? completed,
    Value<int?> completedAt = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => TodoRow(
    id: id ?? this.id,
    title: title ?? this.title,
    note: note ?? this.note,
    dueAt: dueAt ?? this.dueAt,
    source: source ?? this.source,
    completed: completed ?? this.completed,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TodoRow copyWithCompanion(TodosCompanion data) {
    return TodoRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      note: data.note.present ? data.note.value : this.note,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      source: data.source.present ? data.source.value : this.source,
      completed: data.completed.present ? data.completed.value : this.completed,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('note: $note, ')
          ..write('dueAt: $dueAt, ')
          ..write('source: $source, ')
          ..write('completed: $completed, ')
          ..write('completedAt: $completedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    note,
    dueAt,
    source,
    completed,
    completedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.note == this.note &&
          other.dueAt == this.dueAt &&
          other.source == this.source &&
          other.completed == this.completed &&
          other.completedAt == this.completedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TodosCompanion extends UpdateCompanion<TodoRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> note;
  final Value<int> dueAt;
  final Value<String> source;
  final Value<bool> completed;
  final Value<int?> completedAt;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const TodosCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.note = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.source = const Value.absent(),
    this.completed = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodosCompanion.insert({
    required String id,
    required String title,
    this.note = const Value.absent(),
    required int dueAt,
    this.source = const Value.absent(),
    this.completed = const Value.absent(),
    this.completedAt = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       dueAt = Value(dueAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TodoRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? note,
    Expression<int>? dueAt,
    Expression<String>? source,
    Expression<bool>? completed,
    Expression<int>? completedAt,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (note != null) 'note': note,
      if (dueAt != null) 'due_at': dueAt,
      if (source != null) 'source': source,
      if (completed != null) 'completed': completed,
      if (completedAt != null) 'completed_at': completedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodosCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? note,
    Value<int>? dueAt,
    Value<String>? source,
    Value<bool>? completed,
    Value<int?>? completedAt,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return TodosCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      dueAt: dueAt ?? this.dueAt,
      source: source ?? this.source,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<int>(dueAt.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodosCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('note: $note, ')
          ..write('dueAt: $dueAt, ')
          ..write('source: $source, ')
          ..write('completed: $completed, ')
          ..write('completedAt: $completedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TimetablePayloadsTable extends TimetablePayloads
    with TableInfo<$TimetablePayloadsTable, TimetablePayloadRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TimetablePayloadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, payloadJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'timetable_payloads';
  @override
  VerificationContext validateIntegrity(
    Insertable<TimetablePayloadRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TimetablePayloadRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TimetablePayloadRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TimetablePayloadsTable createAlias(String alias) {
    return $TimetablePayloadsTable(attachedDatabase, alias);
  }
}

class TimetablePayloadRow extends DataClass
    implements Insertable<TimetablePayloadRow> {
  final String id;
  final String payloadJson;
  final int updatedAt;
  const TimetablePayloadRow({
    required this.id,
    required this.payloadJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['payload_json'] = Variable<String>(payloadJson);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  TimetablePayloadsCompanion toCompanion(bool nullToAbsent) {
    return TimetablePayloadsCompanion(
      id: Value(id),
      payloadJson: Value(payloadJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory TimetablePayloadRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TimetablePayloadRow(
      id: serializer.fromJson<String>(json['id']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  TimetablePayloadRow copyWith({
    String? id,
    String? payloadJson,
    int? updatedAt,
  }) => TimetablePayloadRow(
    id: id ?? this.id,
    payloadJson: payloadJson ?? this.payloadJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TimetablePayloadRow copyWithCompanion(TimetablePayloadsCompanion data) {
    return TimetablePayloadRow(
      id: data.id.present ? data.id.value : this.id,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TimetablePayloadRow(')
          ..write('id: $id, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, payloadJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TimetablePayloadRow &&
          other.id == this.id &&
          other.payloadJson == this.payloadJson &&
          other.updatedAt == this.updatedAt);
}

class TimetablePayloadsCompanion extends UpdateCompanion<TimetablePayloadRow> {
  final Value<String> id;
  final Value<String> payloadJson;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const TimetablePayloadsCompanion({
    this.id = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TimetablePayloadsCompanion.insert({
    required String id,
    required String payloadJson,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       payloadJson = Value(payloadJson),
       updatedAt = Value(updatedAt);
  static Insertable<TimetablePayloadRow> custom({
    Expression<String>? id,
    Expression<String>? payloadJson,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TimetablePayloadsCompanion copyWith({
    Value<String>? id,
    Value<String>? payloadJson,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return TimetablePayloadsCompanion(
      id: id ?? this.id,
      payloadJson: payloadJson ?? this.payloadJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TimetablePayloadsCompanion(')
          ..write('id: $id, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PluginStatesTable extends PluginStates
    with TableInfo<$PluginStatesTable, PluginStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PluginStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pluginIdMeta = const VerificationMeta(
    'pluginId',
  );
  @override
  late final GeneratedColumn<String> pluginId = GeneratedColumn<String>(
    'plugin_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authStateMeta = const VerificationMeta(
    'authState',
  );
  @override
  late final GeneratedColumn<String> authState = GeneratedColumn<String>(
    'auth_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSyncAtMeta = const VerificationMeta(
    'lastSyncAt',
  );
  @override
  late final GeneratedColumn<int> lastSyncAt = GeneratedColumn<int>(
    'last_sync_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cursorMeta = const VerificationMeta('cursor');
  @override
  late final GeneratedColumn<String> cursor = GeneratedColumn<String>(
    'cursor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    pluginId,
    authState,
    lastSyncAt,
    cursor,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plugin_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<PluginStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('plugin_id')) {
      context.handle(
        _pluginIdMeta,
        pluginId.isAcceptableOrUnknown(data['plugin_id']!, _pluginIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pluginIdMeta);
    }
    if (data.containsKey('auth_state')) {
      context.handle(
        _authStateMeta,
        authState.isAcceptableOrUnknown(data['auth_state']!, _authStateMeta),
      );
    } else if (isInserting) {
      context.missing(_authStateMeta);
    }
    if (data.containsKey('last_sync_at')) {
      context.handle(
        _lastSyncAtMeta,
        lastSyncAt.isAcceptableOrUnknown(
          data['last_sync_at']!,
          _lastSyncAtMeta,
        ),
      );
    }
    if (data.containsKey('cursor')) {
      context.handle(
        _cursorMeta,
        cursor.isAcceptableOrUnknown(data['cursor']!, _cursorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {pluginId};
  @override
  PluginStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PluginStateRow(
      pluginId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plugin_id'],
      )!,
      authState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}auth_state'],
      )!,
      lastSyncAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_sync_at'],
      ),
      cursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cursor'],
      ),
    );
  }

  @override
  $PluginStatesTable createAlias(String alias) {
    return $PluginStatesTable(attachedDatabase, alias);
  }
}

class PluginStateRow extends DataClass implements Insertable<PluginStateRow> {
  final String pluginId;
  final String authState;
  final int? lastSyncAt;
  final String? cursor;
  const PluginStateRow({
    required this.pluginId,
    required this.authState,
    this.lastSyncAt,
    this.cursor,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['plugin_id'] = Variable<String>(pluginId);
    map['auth_state'] = Variable<String>(authState);
    if (!nullToAbsent || lastSyncAt != null) {
      map['last_sync_at'] = Variable<int>(lastSyncAt);
    }
    if (!nullToAbsent || cursor != null) {
      map['cursor'] = Variable<String>(cursor);
    }
    return map;
  }

  PluginStatesCompanion toCompanion(bool nullToAbsent) {
    return PluginStatesCompanion(
      pluginId: Value(pluginId),
      authState: Value(authState),
      lastSyncAt: lastSyncAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncAt),
      cursor: cursor == null && nullToAbsent
          ? const Value.absent()
          : Value(cursor),
    );
  }

  factory PluginStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PluginStateRow(
      pluginId: serializer.fromJson<String>(json['pluginId']),
      authState: serializer.fromJson<String>(json['authState']),
      lastSyncAt: serializer.fromJson<int?>(json['lastSyncAt']),
      cursor: serializer.fromJson<String?>(json['cursor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'pluginId': serializer.toJson<String>(pluginId),
      'authState': serializer.toJson<String>(authState),
      'lastSyncAt': serializer.toJson<int?>(lastSyncAt),
      'cursor': serializer.toJson<String?>(cursor),
    };
  }

  PluginStateRow copyWith({
    String? pluginId,
    String? authState,
    Value<int?> lastSyncAt = const Value.absent(),
    Value<String?> cursor = const Value.absent(),
  }) => PluginStateRow(
    pluginId: pluginId ?? this.pluginId,
    authState: authState ?? this.authState,
    lastSyncAt: lastSyncAt.present ? lastSyncAt.value : this.lastSyncAt,
    cursor: cursor.present ? cursor.value : this.cursor,
  );
  PluginStateRow copyWithCompanion(PluginStatesCompanion data) {
    return PluginStateRow(
      pluginId: data.pluginId.present ? data.pluginId.value : this.pluginId,
      authState: data.authState.present ? data.authState.value : this.authState,
      lastSyncAt: data.lastSyncAt.present
          ? data.lastSyncAt.value
          : this.lastSyncAt,
      cursor: data.cursor.present ? data.cursor.value : this.cursor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PluginStateRow(')
          ..write('pluginId: $pluginId, ')
          ..write('authState: $authState, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('cursor: $cursor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(pluginId, authState, lastSyncAt, cursor);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PluginStateRow &&
          other.pluginId == this.pluginId &&
          other.authState == this.authState &&
          other.lastSyncAt == this.lastSyncAt &&
          other.cursor == this.cursor);
}

class PluginStatesCompanion extends UpdateCompanion<PluginStateRow> {
  final Value<String> pluginId;
  final Value<String> authState;
  final Value<int?> lastSyncAt;
  final Value<String?> cursor;
  final Value<int> rowid;
  const PluginStatesCompanion({
    this.pluginId = const Value.absent(),
    this.authState = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.cursor = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PluginStatesCompanion.insert({
    required String pluginId,
    required String authState,
    this.lastSyncAt = const Value.absent(),
    this.cursor = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : pluginId = Value(pluginId),
       authState = Value(authState);
  static Insertable<PluginStateRow> custom({
    Expression<String>? pluginId,
    Expression<String>? authState,
    Expression<int>? lastSyncAt,
    Expression<String>? cursor,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (pluginId != null) 'plugin_id': pluginId,
      if (authState != null) 'auth_state': authState,
      if (lastSyncAt != null) 'last_sync_at': lastSyncAt,
      if (cursor != null) 'cursor': cursor,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PluginStatesCompanion copyWith({
    Value<String>? pluginId,
    Value<String>? authState,
    Value<int?>? lastSyncAt,
    Value<String?>? cursor,
    Value<int>? rowid,
  }) {
    return PluginStatesCompanion(
      pluginId: pluginId ?? this.pluginId,
      authState: authState ?? this.authState,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      cursor: cursor ?? this.cursor,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (pluginId.present) {
      map['plugin_id'] = Variable<String>(pluginId.value);
    }
    if (authState.present) {
      map['auth_state'] = Variable<String>(authState.value);
    }
    if (lastSyncAt.present) {
      map['last_sync_at'] = Variable<int>(lastSyncAt.value);
    }
    if (cursor.present) {
      map['cursor'] = Variable<String>(cursor.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PluginStatesCompanion(')
          ..write('pluginId: $pluginId, ')
          ..write('authState: $authState, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('cursor: $cursor, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $StandardEventsTable standardEvents = $StandardEventsTable(this);
  late final $TodosTable todos = $TodosTable(this);
  late final $TimetablePayloadsTable timetablePayloads =
      $TimetablePayloadsTable(this);
  late final $PluginStatesTable pluginStates = $PluginStatesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    standardEvents,
    todos,
    timetablePayloads,
    pluginStates,
  ];
}

typedef $$StandardEventsTableCreateCompanionBuilder =
    StandardEventsCompanion Function({
      required String id,
      required String type,
      required String title,
      Value<int?> dueTime,
      required String source,
      Value<String?> rawJson,
      required int fetchedAt,
      Value<int> rowid,
    });
typedef $$StandardEventsTableUpdateCompanionBuilder =
    StandardEventsCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<String> title,
      Value<int?> dueTime,
      Value<String> source,
      Value<String?> rawJson,
      Value<int> fetchedAt,
      Value<int> rowid,
    });

class $$StandardEventsTableFilterComposer
    extends Composer<_$AppDatabase, $StandardEventsTable> {
  $$StandardEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueTime => $composableBuilder(
    column: $table.dueTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StandardEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $StandardEventsTable> {
  $$StandardEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueTime => $composableBuilder(
    column: $table.dueTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StandardEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StandardEventsTable> {
  $$StandardEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get dueTime =>
      $composableBuilder(column: $table.dueTime, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get rawJson =>
      $composableBuilder(column: $table.rawJson, builder: (column) => column);

  GeneratedColumn<int> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$StandardEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StandardEventsTable,
          StandardEventRow,
          $$StandardEventsTableFilterComposer,
          $$StandardEventsTableOrderingComposer,
          $$StandardEventsTableAnnotationComposer,
          $$StandardEventsTableCreateCompanionBuilder,
          $$StandardEventsTableUpdateCompanionBuilder,
          (
            StandardEventRow,
            BaseReferences<
              _$AppDatabase,
              $StandardEventsTable,
              StandardEventRow
            >,
          ),
          StandardEventRow,
          PrefetchHooks Function()
        > {
  $$StandardEventsTableTableManager(
    _$AppDatabase db,
    $StandardEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StandardEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StandardEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StandardEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int?> dueTime = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> rawJson = const Value.absent(),
                Value<int> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StandardEventsCompanion(
                id: id,
                type: type,
                title: title,
                dueTime: dueTime,
                source: source,
                rawJson: rawJson,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                required String title,
                Value<int?> dueTime = const Value.absent(),
                required String source,
                Value<String?> rawJson = const Value.absent(),
                required int fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => StandardEventsCompanion.insert(
                id: id,
                type: type,
                title: title,
                dueTime: dueTime,
                source: source,
                rawJson: rawJson,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StandardEventsTable, StandardEventRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $StandardEventsTable,
                    StandardEventRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StandardEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StandardEventsTable,
      StandardEventRow,
      $$StandardEventsTableFilterComposer,
      $$StandardEventsTableOrderingComposer,
      $$StandardEventsTableAnnotationComposer,
      $$StandardEventsTableCreateCompanionBuilder,
      $$StandardEventsTableUpdateCompanionBuilder,
      (
        StandardEventRow,
        BaseReferences<_$AppDatabase, $StandardEventsTable, StandardEventRow>,
      ),
      StandardEventRow,
      PrefetchHooks Function()
    >;
typedef $$TodosTableCreateCompanionBuilder = TodosCompanion Function({
  required String id,
  required String title,
  Value<String> note,
  required int dueAt,
  Value<String> source,
  Value<bool> completed,
  Value<int?> completedAt,
  required int createdAt,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$TodosTableUpdateCompanionBuilder = TodosCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String> note,
  Value<int> dueAt,
  Value<String> source,
  Value<bool> completed,
  Value<int?> completedAt,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$TodosTableFilterComposer extends Composer<_$AppDatabase, $TodosTable> {
  $$TodosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TodosTableOrderingComposer
    extends Composer<_$AppDatabase, $TodosTable> {
  $$TodosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodosTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodosTable> {
  $$TodosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TodosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodosTable,
          TodoRow,
          $$TodosTableFilterComposer,
          $$TodosTableOrderingComposer,
          $$TodosTableAnnotationComposer,
          $$TodosTableCreateCompanionBuilder,
          $$TodosTableUpdateCompanionBuilder,
          (TodoRow, BaseReferences<_$AppDatabase, $TodosTable, TodoRow>),
          TodoRow,
          PrefetchHooks Function()
        > {
  $$TodosTableTableManager(_$AppDatabase db, $TodosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<int> dueAt = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodosCompanion(
                id: id,
                title: title,
                note: note,
                dueAt: dueAt,
                source: source,
                completed: completed,
                completedAt: completedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String> note = const Value.absent(),
                required int dueAt,
                Value<String> source = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TodosCompanion.insert(
                id: id,
                title: title,
                note: note,
                dueAt: dueAt,
                source: source,
                completed: completed,
                completedAt: completedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TodosTable, TodoRow>(table),
                  BaseReferences<_$AppDatabase, $TodosTable, TodoRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TodosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodosTable,
      TodoRow,
      $$TodosTableFilterComposer,
      $$TodosTableOrderingComposer,
      $$TodosTableAnnotationComposer,
      $$TodosTableCreateCompanionBuilder,
      $$TodosTableUpdateCompanionBuilder,
      (TodoRow, BaseReferences<_$AppDatabase, $TodosTable, TodoRow>),
      TodoRow,
      PrefetchHooks Function()
    >;
typedef $$TimetablePayloadsTableCreateCompanionBuilder =
    TimetablePayloadsCompanion Function({
      required String id,
      required String payloadJson,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$TimetablePayloadsTableUpdateCompanionBuilder =
    TimetablePayloadsCompanion Function({
      Value<String> id,
      Value<String> payloadJson,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$TimetablePayloadsTableFilterComposer
    extends Composer<_$AppDatabase, $TimetablePayloadsTable> {
  $$TimetablePayloadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TimetablePayloadsTableOrderingComposer
    extends Composer<_$AppDatabase, $TimetablePayloadsTable> {
  $$TimetablePayloadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TimetablePayloadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TimetablePayloadsTable> {
  $$TimetablePayloadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TimetablePayloadsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TimetablePayloadsTable,
          TimetablePayloadRow,
          $$TimetablePayloadsTableFilterComposer,
          $$TimetablePayloadsTableOrderingComposer,
          $$TimetablePayloadsTableAnnotationComposer,
          $$TimetablePayloadsTableCreateCompanionBuilder,
          $$TimetablePayloadsTableUpdateCompanionBuilder,
          (
            TimetablePayloadRow,
            BaseReferences<
              _$AppDatabase,
              $TimetablePayloadsTable,
              TimetablePayloadRow
            >,
          ),
          TimetablePayloadRow,
          PrefetchHooks Function()
        > {
  $$TimetablePayloadsTableTableManager(
    _$AppDatabase db,
    $TimetablePayloadsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TimetablePayloadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TimetablePayloadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TimetablePayloadsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TimetablePayloadsCompanion(
                id: id,
                payloadJson: payloadJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String payloadJson,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TimetablePayloadsCompanion.insert(
                id: id,
                payloadJson: payloadJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TimetablePayloadsTable, TimetablePayloadRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $TimetablePayloadsTable,
                    TimetablePayloadRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TimetablePayloadsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TimetablePayloadsTable,
      TimetablePayloadRow,
      $$TimetablePayloadsTableFilterComposer,
      $$TimetablePayloadsTableOrderingComposer,
      $$TimetablePayloadsTableAnnotationComposer,
      $$TimetablePayloadsTableCreateCompanionBuilder,
      $$TimetablePayloadsTableUpdateCompanionBuilder,
      (
        TimetablePayloadRow,
        BaseReferences<
          _$AppDatabase,
          $TimetablePayloadsTable,
          TimetablePayloadRow
        >,
      ),
      TimetablePayloadRow,
      PrefetchHooks Function()
    >;
typedef $$PluginStatesTableCreateCompanionBuilder =
    PluginStatesCompanion Function({
      required String pluginId,
      required String authState,
      Value<int?> lastSyncAt,
      Value<String?> cursor,
      Value<int> rowid,
    });
typedef $$PluginStatesTableUpdateCompanionBuilder =
    PluginStatesCompanion Function({
      Value<String> pluginId,
      Value<String> authState,
      Value<int?> lastSyncAt,
      Value<String?> cursor,
      Value<int> rowid,
    });

class $$PluginStatesTableFilterComposer
    extends Composer<_$AppDatabase, $PluginStatesTable> {
  $$PluginStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get pluginId => $composableBuilder(
    column: $table.pluginId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authState => $composableBuilder(
    column: $table.authState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PluginStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $PluginStatesTable> {
  $$PluginStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get pluginId => $composableBuilder(
    column: $table.pluginId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authState => $composableBuilder(
    column: $table.authState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PluginStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PluginStatesTable> {
  $$PluginStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get pluginId =>
      $composableBuilder(column: $table.pluginId, builder: (column) => column);

  GeneratedColumn<String> get authState =>
      $composableBuilder(column: $table.authState, builder: (column) => column);

  GeneratedColumn<int> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cursor =>
      $composableBuilder(column: $table.cursor, builder: (column) => column);
}

class $$PluginStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PluginStatesTable,
          PluginStateRow,
          $$PluginStatesTableFilterComposer,
          $$PluginStatesTableOrderingComposer,
          $$PluginStatesTableAnnotationComposer,
          $$PluginStatesTableCreateCompanionBuilder,
          $$PluginStatesTableUpdateCompanionBuilder,
          (
            PluginStateRow,
            BaseReferences<_$AppDatabase, $PluginStatesTable, PluginStateRow>,
          ),
          PluginStateRow,
          PrefetchHooks Function()
        > {
  $$PluginStatesTableTableManager(_$AppDatabase db, $PluginStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PluginStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PluginStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PluginStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> pluginId = const Value.absent(),
                Value<String> authState = const Value.absent(),
                Value<int?> lastSyncAt = const Value.absent(),
                Value<String?> cursor = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PluginStatesCompanion(
                pluginId: pluginId,
                authState: authState,
                lastSyncAt: lastSyncAt,
                cursor: cursor,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String pluginId,
                required String authState,
                Value<int?> lastSyncAt = const Value.absent(),
                Value<String?> cursor = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PluginStatesCompanion.insert(
                pluginId: pluginId,
                authState: authState,
                lastSyncAt: lastSyncAt,
                cursor: cursor,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PluginStatesTable, PluginStateRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PluginStatesTable,
                    PluginStateRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PluginStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PluginStatesTable,
      PluginStateRow,
      $$PluginStatesTableFilterComposer,
      $$PluginStatesTableOrderingComposer,
      $$PluginStatesTableAnnotationComposer,
      $$PluginStatesTableCreateCompanionBuilder,
      $$PluginStatesTableUpdateCompanionBuilder,
      (
        PluginStateRow,
        BaseReferences<_$AppDatabase, $PluginStatesTable, PluginStateRow>,
      ),
      PluginStateRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$StandardEventsTableTableManager get standardEvents =>
      $$StandardEventsTableTableManager(_db, _db.standardEvents);
  $$TodosTableTableManager get todos =>
      $$TodosTableTableManager(_db, _db.todos);
  $$TimetablePayloadsTableTableManager get timetablePayloads =>
      $$TimetablePayloadsTableTableManager(_db, _db.timetablePayloads);
  $$PluginStatesTableTableManager get pluginStates =>
      $$PluginStatesTableTableManager(_db, _db.pluginStates);
}
