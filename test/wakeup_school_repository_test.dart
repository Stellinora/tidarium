import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/features/timetable/import/data/wakeup_school_repository.dart';
import 'package:tidarium/features/timetable/import/models/wakeup_school.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses and maps the supported WakeUp families', () {
    final schools = parseWakeUpSchools(
      jsonEncode({
        'data': [
          {
            'name': '测试大学',
            'sortKey': 'C',
            'type': 'zf',
            'url': 'jw.example.edu.cn',
          },
          {
            'name': '青果大学',
            'sortKey': 'Q',
            'type': 'qz_with_node',
            'url': 'https://qingguo.example.edu.cn/login',
          },
          {
            'name': 'URP 大学',
            'sortKey': 'U',
            'type': 'urp_new',
            'url': 'http://urp.example.edu.cn/',
          },
          {
            'name': '超星大学',
            'sortKey': 'X',
            'type': 'login_chaoxing',
            'url': 'https://chaoxing.example.edu.cn/',
          },
          {
            'name': '未适配大学',
            'sortKey': 'W',
            'type': 'kingo_new',
            'url': 'https://kingo.example.edu.cn/',
          },
        ],
      }),
    );

    expect(schools.length, 5);
    WakeUpSchool named(String name) =>
        schools.firstWhere((school) => school.name == name);

    expect(named('测试大学').url.toString(), 'https://jw.example.edu.cn');
    expect(named('测试大学').family, WakeUpFamily.zhengfang);
    expect(named('青果大学').family, WakeUpFamily.qingguo);
    expect(named('URP 大学').family, WakeUpFamily.urp);
    expect(named('超星大学').family, WakeUpFamily.chaoxing);
    expect(named('未适配大学').family, isNull);
    expect(named('未适配大学').canImport, isFalse);
    expect(named('未适配大学').typeLabel, '金智');
  });

  test('skips blank, invalid and credential-bearing URLs', () {
    final schools = parseWakeUpSchools(
      jsonEncode({
        'data': [
          {'name': '空地址', 'sortKey': 'K', 'type': 'zf', 'url': ''},
          {
            'name': '错误协议',
            'sortKey': 'C',
            'type': 'zf',
            'url': 'ftp://x.example',
          },
          {
            'name': '带凭据',
            'sortKey': 'D',
            'type': 'zf',
            'url': 'https://user:pass@example.edu.cn',
          },
          {
            'name': '有效学校',
            'sortKey': 'Y',
            'type': 'zf',
            'url': 'https://valid.example.edu.cn/login',
          },
        ],
      }),
    );

    expect(schools, hasLength(1));
    expect(schools.single.name, '有效学校');
  });

  test('sorts letter initials before unknown initials', () {
    final schools = parseWakeUpSchools(
      jsonEncode({
        'data': [
          {
            'name': 'B 大学',
            'sortKey': 'B',
            'type': 'zf',
            'url': 'https://b.example',
          },
          {
            'name': '未知',
            'sortKey': '0',
            'type': 'zf',
            'url': 'https://x.example',
          },
          {
            'name': 'A 大学',
            'sortKey': 'A',
            'type': 'zf',
            'url': 'https://a.example',
          },
        ],
      }),
    );

    expect(schools.map((item) => item.name), ['A 大学', 'B 大学', '未知']);
  });

  test('loads the bundled school catalog', () async {
    final schools = await WakeUpSchoolRepository().loadSchools();

    expect(schools, hasLength(1941));
    expect(schools.where((school) => school.canImport), hasLength(1278));
    expect(schools.where((school) => !school.canImport), isNotEmpty);
  });
}
