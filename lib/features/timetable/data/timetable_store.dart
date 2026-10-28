import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../model/timetable_data.dart';

abstract interface class TimetableStore {
  Future<TimetableData?> load();

  Future<void> save(TimetableData data);
}

class InMemoryTimetableStore implements TimetableStore {
  InMemoryTimetableStore({TimetableData? initial}) : _data = initial;

  TimetableData? _data;

  @override
  Future<TimetableData?> load() async => _data;

  @override
  Future<void> save(TimetableData data) async {
    _data = data;
  }
}

class JsonFileTimetableStore implements TimetableStore {
  JsonFileTimetableStore({this.fileName = 'timetable.json'});

  final String fileName;

  Future<File> _resolveFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }

  @override
  Future<TimetableData?> load() async {
    try {
      final file = await _resolveFile();
      if (!await file.exists()) return null;

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;

      return TimetableData.fromJson(decoded.cast<String, Object?>());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(TimetableData data) async {
    final file = await _resolveFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(data.toJson()), flush: true);
  }
}
