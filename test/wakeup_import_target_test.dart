import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/features/timetable/import/data/adapter_repository.dart';
import 'package:tidarium/features/timetable/import/data/wakeup_import_target.dart';
import 'package:tidarium/features/timetable/import/models/school_models.dart';
import 'package:tidarium/features/timetable/import/models/wakeup_school.dart';

class _FakeAdapterRepository extends AdapterRepository {
  @override
  Future<List<SchoolEntry>> loadSchools({bool forceRefresh = false}) async {
    return const [
      SchoolEntry(
        id: 'zhengfang_jiaowu',
        name: '正方教务-通用教务',
        initial: 'Z',
        resourceFolder: 'zhengfang_jiaowu',
      ),
    ];
  }

  @override
  Future<List<SchoolAdapter>> loadAdapters(
    SchoolEntry school, {
    bool forceRefresh = false,
  }) async {
    return const [
      SchoolAdapter(
        adapterId: 'zhengfang_01',
        adapterName: '正方教务 HTML 通用读取',
        category: 'GENERAL_TOOL',
        assetJsPath: 'zhengfang_01.js',
        importUrl: '',
        maintainer: '星海转',
        description: '登录后读取课表页面',
      ),
    ];
  }
}

void main() {
  test('builds a WebImportPage target with the WakeUp school URL', () async {
    final target = await resolveWakeUpImportTarget(
      school: WakeUpSchool(
        name: '测试大学',
        initial: 'C',
        type: 'zf',
        url: Uri.parse('https://jw.test.edu.cn/login'),
        family: WakeUpFamily.zhengfang,
      ),
      repository: _FakeAdapterRepository(),
    );

    expect(target.school.id, 'zhengfang_jiaowu');
    expect(target.school.name, '测试大学');
    expect(target.school.resourceFolder, 'zhengfang_jiaowu');
    expect(target.adapter.adapterId, 'zhengfang_01');
    expect(target.adapter.importUrl, 'https://jw.test.edu.cn/login');
    expect(target.adapter.adapterName, contains('测试大学'));
  });

  test('uses the local HDU parser and direct new academic entry', () async {
    final target = await resolveWakeUpImportTarget(
      school: WakeUpSchool(
        name: '杭州电子科技大学',
        initial: 'H',
        type: 'zf',
        url: Uri.parse('https://newjw.hdu.edu.cn/sso/driot4login'),
        family: WakeUpFamily.zhengfang,
      ),
      repository: _FakeAdapterRepository(),
    );

    expect(target.school.id, 'hdu_jiaowu');
    expect(
      target.adapter.importUrl,
      'https://newjw.hdu.edu.cn/sso/driot4login',
    );
    expect(target.localScript, contains('xskbcx_cxXsgrkb.html'));
  });

  test('rejects unsupported WakeUp schools', () async {
    final school = WakeUpSchool(
      name: '未适配大学',
      initial: 'W',
      type: 'kingo_new',
      url: Uri.parse('https://kingo.example.edu.cn/'),
      family: null,
    );

    await expectLater(
      resolveWakeUpImportTarget(
        school: school,
        repository: _FakeAdapterRepository(),
      ),
      throwsA(isA<WakeUpImportException>()),
    );
  });
}
