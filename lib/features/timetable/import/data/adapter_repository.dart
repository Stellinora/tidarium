import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart';

import '../models/school_models.dart';

const List<String> defaultAdapterRepoBaseUrls = [
  'https://raw.githubusercontent.com/ShiGuangSchedule/shiguang_warehouse/main',
  'https://gitee.com/XingHeYuZhuan-gh/shiguang_warehouse/raw/main',
];

class AdapterRepository {
  AdapterRepository({Dio? dio, List<String>? baseUrls})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 25),
              headers: const {'User-Agent': 'Tidarium'},
            ),
          ),
      baseUrls = baseUrls ?? defaultAdapterRepoBaseUrls;

  final Dio _dio;
  final List<String> baseUrls;

  Future<List<SchoolEntry>> loadSchools({bool forceRefresh = false}) async {
    final content = await _fetchText(
      'index/root_index.yaml',
      'index/root_index.yaml',
      forceRefresh: forceRefresh,
    );
    final document = loadYaml(content);
    final schoolsNode = document is Map ? document['schools'] : null;
    if (schoolsNode is! YamlList) {
      throw const FormatException('学校索引格式不正确');
    }

    final schools = <SchoolEntry>[];
    for (final item in schoolsNode) {
      if (item is! Map) continue;
      final id = _string(item['id']);
      final name = _string(item['name']);
      if (id.isEmpty || name.isEmpty) continue;
      schools.add(
        SchoolEntry(
          id: id,
          name: name,
          initial: _string(item['initial']),
          resourceFolder: _string(item['resource_folder']).isEmpty
              ? id
              : _string(item['resource_folder']),
        ),
      );
    }

    schools.sort((a, b) {
      final byInitial = a.initial.toUpperCase().compareTo(
        b.initial.toUpperCase(),
      );
      if (byInitial != 0) return byInitial;
      return a.name.compareTo(b.name);
    });
    return List.unmodifiable(schools);
  }

  Future<List<SchoolAdapter>> loadAdapters(
    SchoolEntry school, {
    bool forceRefresh = false,
  }) async {
    final content = await _fetchText(
      'resources/${_encodePath(school.resourceFolder)}/adapters.yaml',
      'resources/${school.resourceFolder}/adapters.yaml',
      forceRefresh: forceRefresh,
    );
    final document = loadYaml(content);
    final adaptersNode = document is Map ? document['adapters'] : null;
    if (adaptersNode is! YamlList) {
      throw const FormatException('适配器索引格式不正确');
    }

    final adapters = <SchoolAdapter>[];
    for (final item in adaptersNode) {
      if (item is! Map) continue;
      final id = _string(item['adapter_id']);
      final name = _string(item['adapter_name']);
      if (id.isEmpty || name.isEmpty) continue;
      adapters.add(
        SchoolAdapter(
          adapterId: id,
          adapterName: name,
          category: _string(item['category']),
          assetJsPath: _string(item['asset_js_path']),
          importUrl: _string(item['import_url']),
          maintainer: _string(item['maintainer']),
          description: _string(item['description']),
        ),
      );
    }

    return List.unmodifiable(adapters);
  }

  Future<String> loadAdapterScript(
    SchoolEntry school,
    SchoolAdapter adapter, {
    bool forceRefresh = false,
  }) async {
    final assetPath = adapter.assetJsPath.isNotEmpty
        ? adapter.assetJsPath
        : '${adapter.adapterId}.js';

    return _fetchText(
      'resources/${_encodePath(school.resourceFolder)}/${_encodePath(assetPath)}',
      'resources/${school.resourceFolder}/$assetPath',
      forceRefresh: forceRefresh,
    );
  }

  Future<String> _fetchText(
    String relativeUrl,
    String cacheRelativePath, {
    required bool forceRefresh,
  }) async {
    final cacheFile = await _cacheFile(cacheRelativePath);
    final hasCache = await cacheFile.exists();

    if (!forceRefresh && hasCache) {
      return cacheFile.readAsString();
    }

    Object? lastError;
    for (final baseUrl in baseUrls) {
      try {
        final response = await _dio.get<String>(
          '$baseUrl/$relativeUrl',
          options: Options(
            responseType: ResponseType.plain,
            headers: const {'Accept': 'text/plain'},
          ),
        );
        final text = response.data;
        if (text == null) {
          throw const FormatException('服务器返回了空内容');
        }
        await cacheFile.parent.create(recursive: true);
        await cacheFile.writeAsString(text, flush: true);
        return text;
      } catch (error) {
        lastError = error;
      }
    }

    if (hasCache) return cacheFile.readAsString();
    throw AdapterRepositoryException('下载适配器数据失败: $lastError');
  }

  Future<File> _cacheFile(String relativePath) async {
    final support = await getApplicationSupportDirectory();
    final root = Directory(
      '${support.path}${Platform.pathSeparator}adapter_repo',
    );
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    final normalized = relativePath.replaceAll('/', Platform.pathSeparator);
    return File('${root.path}${Platform.pathSeparator}$normalized');
  }

  String _encodePath(String value) {
    return value
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');
  }

  String _string(Object? value) => value?.toString().trim() ?? '';
}

class AdapterRepositoryException implements Exception {
  const AdapterRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
