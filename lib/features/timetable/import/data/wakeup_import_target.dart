import '../models/school_models.dart';
import '../models/wakeup_school.dart';
import 'adapter_repository.dart';

class WakeUpImportTarget {
  const WakeUpImportTarget({required this.school, required this.adapter});

  final SchoolEntry school;
  final SchoolAdapter adapter;
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
