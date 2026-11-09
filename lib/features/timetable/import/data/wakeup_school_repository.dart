import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/wakeup_school.dart';

const String wakeUpSchoolAssetPath = 'assets/wakeup_schools.json';

class WakeUpSchoolRepository {
  WakeUpSchoolRepository({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<List<WakeUpSchool>> loadSchools() async {
    final raw = await _bundle.loadString(wakeUpSchoolAssetPath);
    return parseWakeUpSchools(raw);
  }
}

List<WakeUpSchool> parseWakeUpSchools(String raw) {
  final decoded = jsonDecode(raw);
  final data = decoded is Map ? decoded['data'] : null;
  if (data is! List) {
    throw const FormatException('WakeUp 学校清单格式不正确');
  }

  final schools = <WakeUpSchool>[];
  for (final item in data) {
    if (item is! Map) continue;
    final name = _string(item['name']);
    final rawUrl = _schoolUrlOverrides[name] ?? _string(item['url']);
    final url = _normalizeUrl(rawUrl);
    if (name.isEmpty || url == null) continue;

    final sortKey = _string(item['sortKey']);
    final initial = RegExp(r'^[A-Za-z]$').hasMatch(sortKey)
        ? sortKey.toUpperCase()
        : '#';
    final type = _string(item['type']);
    schools.add(
      WakeUpSchool(
        name: name,
        initial: initial,
        type: type,
        url: url,
        family: _familyForType(type),
      ),
    );
  }

  schools.sort((a, b) {
    final byInitial = _initialRank(a.initial)
        .compareTo(_initialRank(b.initial));
    if (byInitial != 0) return byInitial;
    final byInitialName = a.initial.compareTo(b.initial);
    if (byInitialName != 0) return byInitialName;
    return a.name.compareTo(b.name);
  });
  return List.unmodifiable(schools);
}

WakeUpFamily? _familyForType(String type) {
  if (_isQiangzhiType(type)) return WakeUpFamily.qiangzhi;
  if (_zhengfangTypes.contains(type)) return WakeUpFamily.zhengfang;
  if (_qingguoTypes.contains(type)) return WakeUpFamily.qingguo;
  if (_urpTypes.contains(type)) return WakeUpFamily.urp;
  if (_chaoxingTypes.contains(type)) return WakeUpFamily.chaoxing;
  return null;
}

bool _isQiangzhiType(String type) {
  return type.startsWith('qz') || type == 'jlict_qz_old';
}

Uri? _normalizeUrl(String raw) {
  var value = raw.trim();
  if (value.isEmpty) return null;
  if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(value)) {
    value = 'https://$value';
  }

  final uri = Uri.tryParse(value);
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

int _initialRank(String initial) {
  return initial == '#' ? 1 : 0;
}

String _string(Object? value) => value?.toString().trim() ?? '';

const Map<String, String> _schoolUrlOverrides = {
  '杭州电子科技大学': 'https://newjw.hdu.edu.cn/sso/driot4login',
  '绍兴文理学院': 'https://jwxt.usx.edu.cn/jwglxt/xtgl/login_slogin.html',
  '绍兴理工学院': 'https://jwxt.zsit.edu.cn/jwglxt/xtgl/login_slogin.html',
  '绍兴文理学院元培学院': 'https://jwxt.zsit.edu.cn/jwglxt/xtgl/login_slogin.html',
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

const Set<String> _zhengfangTypes = {'zf'};

const Set<String> _qingguoTypes = {'kingo_new'};

const Set<String> _urpTypes = {'urp', 'urp_new'};

const Set<String> _chaoxingTypes = {'login_chaoxing'};
