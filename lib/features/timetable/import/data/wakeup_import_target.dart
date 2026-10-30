import '../adapters/hdu_adapter.dart';
import '../models/school_models.dart';
import '../models/wakeup_school.dart';
import 'adapter_repository.dart';

class WakeUpImportTarget {
  const WakeUpImportTarget({
    required this.school,
    required this.adapter,
    this.localScript,
  });

  final SchoolEntry school;
  final SchoolAdapter adapter;
  final String? localScript;
}

class WakeUpImportException implements Exception {
  const WakeUpImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<WakeUpImportTarget> resolveWakeUpImportTarget({
  required WakeUpSchool school,
  required AdapterRepository repository,
}) async {
  if (school.name == '杭州电子科技大学' || school.url.host.endsWith('hdu.edu.cn')) {
    return WakeUpImportTarget(
      school: SchoolEntry(
        id: 'hdu_jiaowu',
        name: school.name,
        initial: school.initial,
        resourceFolder: 'hdu_jiaowu',
      ),
      adapter: SchoolAdapter(
        adapterId: 'hdu_01',
        adapterName: '${school.name} · 原生教务解析',
        category: 'BACHELOR_AND_ASSOCIATE',
        assetJsPath: '',
        importUrl: 'https://newjw.hdu.edu.cn/sso/driot4login',
        maintainer: 'Tidarium',
        description: '读取杭电新教务的课表、作息和学期日期',
      ),
      localScript: hduAdapterScript,
    );
  }

  final family = school.family;
  if (family == null) {
    throw const WakeUpImportException('该校暂时没有可用的通用教务适配器');
  }

  final genericSchools = await repository.loadSchools();
  SchoolEntry? genericSchool;
  for (final item in genericSchools) {
    if (item.id == family.schoolId) {
      genericSchool = item;
      break;
    }
  }
  if (genericSchool == null) {
    throw WakeUpImportException('未找到「${family.label}」通用适配器');
  }

  final genericAdapters = await repository.loadAdapters(genericSchool);
  if (genericAdapters.isEmpty) {
    throw WakeUpImportException('「${family.label}」通用适配器没有可用脚本');
  }

  SchoolAdapter? genericAdapter;
  for (final item in genericAdapters) {
    if (item.adapterId == family.adapterId) {
      genericAdapter = item;
      break;
    }
  }
  genericAdapter ??= genericAdapters.first;

  return WakeUpImportTarget(
    school: SchoolEntry(
      id: genericSchool.id,
      name: school.name,
      initial: school.initial,
      resourceFolder: genericSchool.resourceFolder,
    ),
    adapter: SchoolAdapter(
      adapterId: genericAdapter.adapterId,
      adapterName: '${school.name} · ${genericAdapter.adapterName}',
      category: genericAdapter.category,
      assetJsPath: genericAdapter.assetJsPath,
      importUrl: school.url.toString(),
      maintainer: genericAdapter.maintainer,
      description: genericAdapter.description,
    ),
  );
}
