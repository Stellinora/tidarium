import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

@DataClassName('StandardEventRow')
class StandardEvents extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get title => text()();
  IntColumn get dueTime => integer().nullable()();
  TextColumn get source => text()();
  TextColumn get rawJson => text().nullable()();
  IntColumn get fetchedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TodoRow')
class Todos extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get dueAt => integer()();
  TextColumn get source => text().withDefault(const Constant(''))();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  IntColumn get completedAt => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// 所属课表 profile，v2 新增；迁移期允许为空字符串，启动时回填。
  TextColumn get profileId => text().withDefault(const Constant(''))();

  /// 所属归属，v2 新增；迁移期允许为空字符串，启动时回填到默认组。
  TextColumn get ownerId => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('OwnerRow')
class Owners extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text()();
  TextColumn get kind => text()();
  TextColumn get name => text()();
  TextColumn get platform => text().nullable()();
  TextColumn get origin => text().withDefault(const Constant('manual'))();
  BoolColumn get nameCustom => boolean().withDefault(const Constant(false))();
  IntColumn get colorIndex => integer().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 归属与外部对象的绑定：目前只有课程（refType = course，refId = course.id）。
@DataClassName('OwnerRefRow')
class OwnerRefs extends Table {
  TextColumn get ownerId => text()();
  TextColumn get profileId => text()();
  TextColumn get refType => text()();
  TextColumn get refId => text()();

  @override
  Set<Column<Object>> get primaryKey => {refType, refId};
}

@DataClassName('TagRow')
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text()();
  TextColumn get name => text()();
  TextColumn get nameNorm => text()();
  IntColumn get colorIndex => integer().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {profileId, nameNorm},
  ];
}

@DataClassName('TodoTagRow')
class TodoTags extends Table {
  TextColumn get todoId => text()();
  TextColumn get tagId => text()();

  @override
  Set<Column<Object>> get primaryKey => {todoId, tagId};
}

@DataClassName('TimetablePayloadRow')
class TimetablePayloads extends Table {
  TextColumn get id => text()();
  TextColumn get payloadJson => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('PluginStateRow')
class PluginStates extends Table {
  TextColumn get pluginId => text()();
  TextColumn get authState => text()();
  IntColumn get lastSyncAt => integer().nullable()();
  TextColumn get cursor => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {pluginId};
}

@DriftDatabase(
  tables: [
    StandardEvents,
    Todos,
    Owners,
    OwnerRefs,
    Tags,
    TodoTags,
    TimetablePayloads,
    PluginStates,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _createIndexes();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(owners);
        await m.createTable(ownerRefs);
        await m.createTable(tags);
        await m.createTable(todoTags);
        await m.addColumn(todos, todos.profileId);
        await m.addColumn(todos, todos.ownerId);
        await _createIndexes();
      }
    },
  );

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_todos_profile_due '
      'ON todos (profile_id, due_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_owners_profile_kind '
      'ON owners (profile_id, kind)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_owner_refs_profile '
      'ON owner_refs (profile_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_todo_tags_tag ON todo_tags (tag_id)',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_owners_default '
      'ON owners (profile_id) WHERE is_default = 1',
    );
  }
}

LazyDatabase openAppDatabase() {
  return LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}tidarium.sqlite');
    return NativeDatabase.createInBackground(file);
  });
}
