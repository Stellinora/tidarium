import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../model/timetable_data.dart';
import '../model/timetable_library.dart';

abstract class TimetableStore {
  Future<TimetableLibrary?> loadLibrary();

  Future<void> saveLibrary(TimetableLibrary library);

  Future<TimetableData?> load() async => (await loadLibrary())?.active;

  Future<void> save(TimetableData data) async {
    final current = await loadLibrary();
    final library = current == null
        ? TimetableLibrary.single(data)
        : current.replace(data);
    await saveLibrary(library);
  }
}

class InMemoryTimetableStore extends TimetableStore {
  InMemoryTimetableStore({TimetableData? initial})
    : _library = initial == null ? null : TimetableLibrary.single(initial);

  TimetableLibrary? _library;

  @override
  Future<TimetableLibrary?> loadLibrary() async => _library;

  @override
  Future<void> saveLibrary(TimetableLibrary library) async {
    _library = library;
  }
}

class JsonFileTimetableStore extends TimetableStore {
  JsonFileTimetableStore({this.fileName = 'timetable.json'});

  final String fileName;

  Future<File> _resolveFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }

  @override
  Future<TimetableLibrary?> loadLibrary() async {
    try {
      final file = await _resolveFile();
      if (!await file.exists()) return null;

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;

      return TimetableLibrary.fromJson(decoded.cast<String, Object?>());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveLibrary(TimetableLibrary library) async {
    final file = await _resolveFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(library.toJson()), flush: true);
  }
}
