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
    final url = _normalizeUrl(_string(item['url']));
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
  if (_zhengfangTypes.contains(type)) return WakeUpFamily.zhengfang;
  if (_qingguoTypes.contains(type)) return WakeUpFamily.qingguo;
  if (_urpTypes.contains(type)) return WakeUpFamily.urp;
  if (_chaoxingTypes.contains(type)) return WakeUpFamily.chaoxing;
  return null;
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

const Set<String> _zhengfangTypes = {'zf'};

const Set<String> _qingguoTypes = {
  'qz',
  'qz_2017',
  'qz_ahut',
  'qz_bjfu',
  'qz_br',
  'qz_crazy',
  'qz_ecust',
  'qz_fspt',
  'qz_njust',
  'qz_old',
  'qz_single_node',
  'qz_ustb',
  'qz_with_node',
};

const Set<String> _urpTypes = {'urp', 'urp_new'};

const Set<String> _chaoxingTypes = {'login_chaoxing'};
