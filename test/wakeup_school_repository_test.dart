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
            'type': 'kingo_new',
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
            'name': '强智大学',
            'sortKey': 'Q',
            'type': 'qz_with_node',
            'url': 'https://qiangzhi.example.edu.cn/',
          },
          {
            'name': '金智大学',
            'sortKey': 'J',
            'type': 'jz',
            'url': 'https://jinzhi.example.edu.cn/',
          },
          {
            'name': '乘方大学',
            'sortKey': 'C',
            'type': 'cf',
            'url': 'https://chengfang.example.edu.cn/',
          },
          {
            'name': '树维大学',
            'sortKey': 'S',
            'type': 'shuwei_new',
            'url': 'https://shuwei.example.edu.cn/',
          },
          {
            'name': '南软大学',
            'sortKey': 'N',
            'type': 'south_soft',
            'url': 'https://southsoft.example.edu.cn/',
          },
        ],
      }),
    );

    expect(schools.length, 9);
    WakeUpSchool named(String name) =>
        schools.firstWhere((school) => school.name == name);

    expect(named('测试大学').url.toString(), 'https://jw.example.edu.cn');
    expect(named('测试大学').family, WakeUpFamily.zhengfang);
    expect(named('青果大学').family, WakeUpFamily.qingguo);
    expect(named('URP 大学').family, WakeUpFamily.urp);
    expect(named('超星大学').family, WakeUpFamily.chaoxing);
    expect(named('强智大学').family, WakeUpFamily.qiangzhi);
    expect(named('强智大学').typeLabel, '强智');
    expect(named('金智大学').family, isNull);
    expect(named('金智大学').typeLabel, '金智');
    expect(named('乘方大学').family, isNull);
    expect(named('乘方大学').typeLabel, '乘方');
    expect(named('树维大学').family, isNull);
    expect(named('树维大学').typeLabel, '树维');
    expect(named('南软大学').family, isNull);
    expect(named('南软大学').typeLabel, '南软');
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

  test('uses the direct HDU new academic SSO entry', () {
    final schools = parseWakeUpSchools(
      jsonEncode({
        'data': [
          {
            'name': '杭州电子科技大学',
            'sortKey': 'H',
            'type': 'zf',
            'url': 'https://sso.hdu.edu.cn/login?service=https%3A%2F%2Fwebvpn.hdu.edu.cn',
          },
        ],
      }),
    );

    expect(
      schools.single.url.toString(),
      'https://newjw.hdu.edu.cn/sso/driot4login',
    );
  });

  test('uses the current Shaoxing University academic entries', () {
    final schools = parseWakeUpSchools(
      jsonEncode({
        'data': [
          {
            'name': '绍兴文理学院',
            'sortKey': 'S',
            'type': 'zf',
            'url': 'http://jw.usx.edu.cn/',
          },
          {
            'name': '绍兴文理学院元培学院',
            'sortKey': 'S',
            'type': 'zf',
            'url': 'http://www.ypc.edu.cn/jwgl.htm',
          },
        ],
      }),
    );

    final named = {for (final school in schools) school.name: school};
    expect(
      named['绍兴文理学院']?.url.toString(),
      'https://jwxt.usx.edu.cn/jwglxt/xtgl/login_slogin.html',
    );
    expect(
      named['绍兴文理学院元培学院']?.url.toString(),
      'https://jwxt.zsit.edu.cn/jwglxt/xtgl/login_slogin.html',
    );
  });

  test('uses verified current academic URLs', () {
    const overrides = {
      '绍兴理工学院':
          'https://jwxt.zsit.edu.cn/jwglxt/xtgl/login_slogin.html',
      '武汉科技大学': 'https://bkjx.wust.edu.cn/jsxsd/',
      '武汉商学院': 'https://jw.wbu.edu.cn/jsxsd/',
      '西安财经大学': 'http://jiaowu.xaufe.edu.cn/',
      '青岛滨海学院': 'http://jwgl.qdbhu.edu.cn/',
      '湖南信息学院': 'https://jwgl.hnuit.edu.cn/',
      '山东理工大学': 'https://jw.sdut.edu.cn/jwglxt/',
      '汉口学院': 'http://113.57.132.2:83/xtgl/login_slogin.html',
      '湖南生物机电职业技术学院': 'http://jwxt.hnbemc.cn:81/sso.jsp',
      '浙江大学': 'https://zdbk.zju.edu.cn/jwglxt/xtgl/login_slogin.html',
    };

    final schools = parseWakeUpSchools(
      jsonEncode({
        'data': [
          for (final name in overrides.keys)
            {
              'name': name,
              'sortKey': 'W',
              'type': 'zf',
              'url': 'https://stale.example/',
            },
        ],
      }),
    );

    final actual = {for (final school in schools) school.name: school.url.toString()};
    expect(actual, overrides);
  });

  test('loads the bundled school catalog', () async {
    final schools = await WakeUpSchoolRepository().loadSchools();

    expect(schools, hasLength(1941));
    expect(schools.where((school) => school.canImport), hasLength(1438));
    expect(schools.where((school) => !school.canImport), isNotEmpty);
  });
}
