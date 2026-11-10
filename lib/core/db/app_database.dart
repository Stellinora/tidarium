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

  @override
  Set<Column<Object>> get primaryKey => {id};
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
  tables: [StandardEvents, Todos, TimetablePayloads, PluginStates],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}

LazyDatabase openAppDatabase() {
  return LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}tidarium.sqlite');
    return NativeDatabase.createInBackground(file);
  });
}
