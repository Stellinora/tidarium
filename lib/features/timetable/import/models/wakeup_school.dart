enum WakeUpFamily {
  zhengfang(
    label: '正方',
    schoolId: 'zhengfang_jiaowu',
    adapterId: 'zhengfang_01',
  ),
  qiangzhi(
    label: '强智',
    schoolId: 'qiangzhi_jiaowu',
    adapterId: 'qiangzhi_01',
  ),
  qingguo(label: '青果', schoolId: 'qingguo_jiaowu', adapterId: 'qingguo_01'),
  chengfang(
    label: '乘方',
    schoolId: 'chengfang_jiaowu',
    adapterId: 'chengfang_01',
  ),
  jinzhi(label: '金智', schoolId: 'jinzhi_jiaowu', adapterId: 'mtt_01'),
  shuweiMtt(label: '树维', schoolId: 'shuwei_mtt_jiaowu', adapterId: 'mtt_01'),
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
    if (type.startsWith('qz') || type == 'jlict_qz_old') return '强智';
    if (type == 'kingo_new') return '青果';
    if (type == 'jz') return '金智';
    if (type.startsWith('shuwei') || type.contains('_shuwei')) return '树维';
    if (type == 'cf' || type == 'cf_new') return '乘方';
    if (type == 'south_soft') return '南软';
    return type.isEmpty ? '未知' : type;
  }
}
