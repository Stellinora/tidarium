enum WakeUpFamily {
  zhengfang(
    label: '正方',
    schoolId: 'zhengfang_jiaowu',
    adapterId: 'zhengfang_01',
  ),
  qingguo(label: '青果', schoolId: 'qingguo_jiaowu', adapterId: 'qingguo_01'),
  urp(label: 'URP', schoolId: 'urp_jiaowu', adapterId: 'urp_01'),
  chaoxing(label: '超星', schoolId: 'chaoxing_jiaowu', adapterId: 'chaoxing');

  const WakeUpFamily({
    required this.label,
    required this.schoolId,
    required this.adapterId,
  });

  final String label;
  final String schoolId;
  final String adapterId;
}

class WakeUpSchool {
  const WakeUpSchool({
    required this.name,
    required this.initial,
    required this.type,
    required this.url,
    required this.family,
  });

  final String name;
  final String initial;
  final String type;
  final Uri url;
  final WakeUpFamily? family;

  bool get canImport => family != null;

  String get typeLabel {
    final matched = family;
    if (matched != null) return matched.label;
    if (type == 'kingo_new' || type == 'jz') return '金智';
    if (type.startsWith('shuwei') || type.contains('_shuwei')) return '树维';
    if (type == 'cf' || type == 'cf_new') return '专用教务';
    if (type == 'south_soft') return '南软';
    return type.isEmpty ? '未知' : type;
  }
}
