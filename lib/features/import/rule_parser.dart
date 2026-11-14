import '../owners/model/owner.dart';
import 'model/import_draft.dart';

final RegExp _actionPattern = RegExp(
  r'提交|上交|截止|报名|开会|集合|完成|准备|参加|缴纳|领取|训练|值班|例会|活动|比赛|签到|上课|考试|作业',
);

/// 无模型时的兜底解析：纯规则，不调用任何接口。
/// 质量不如大模型，但保证「填一张截图就能出一条待办」。
List<ImportDraft> parseRules({
  required String text,
  required DateTime now,
  List<Owner> owners = const [],
}) {
  final drafts = <ImportDraft>[];
  final seen = <String>{};
  final lines = text
      .split(RegExp(r'[\r\n]+'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);

  for (final raw in lines) {
    if (raw.length < 4) continue;

    final hasAction = _actionPattern.hasMatch(raw);
    // 纯招呼语、没有动作的句子直接跳过；带动作的招呼行保留（如「各位：11月20日前提交」）。
    if (!hasAction && RegExp(r'^(各位|同学们|大家|通知|注意|请注)').hasMatch(raw)) {
      continue;
    }
    if (!hasAction) continue;

    final date = _parseDue(raw, now);

    final title = _cleanTitle(raw, now);
    if (title.length < 2) continue;

    final key = '${title.toLowerCase()}|${date?.toIso8601String() ?? ''}';
    if (seen.contains(key)) continue;
    seen.add(key);

    final owner = _matchOwner(raw, owners);
    drafts.add(
      ImportDraft(
        id: newDraftId(),
        title: title,
        dueAt: date,
        kind: owner?.kind ?? _guessKind(raw),
        ownerId: owner?.id,
        materials: _materials(raw),
        source: '本地识别',
        confidence: date == null ? 0.4 : 0.6,
        warnings: [if (date == null) '时间待补'],
      ),
    );
    if (drafts.length >= 10) break;
  }

  return List.unmodifiable(drafts);
}

DateTime? _parseDue(String line, DateTime now) {
  final time = _parseTime(line);

  final absolute = RegExp(r'(20\d{2})[-/.](\d{1,2})[-/.](\d{1,2})').firstMatch(line);
  if (absolute != null) {
    return _at(
      int.parse(absolute.group(1)!),
      int.parse(absolute.group(2)!),
      int.parse(absolute.group(3)!),
      time,
    );
  }

  final monthDay = RegExp(r'(\d{1,2})月(\d{1,2})日').firstMatch(line);
  if (monthDay != null) {
    return _at(
      now.year,
      int.parse(monthDay.group(1)!),
      int.parse(monthDay.group(2)!),
      time,
    );
  }

  if (line.contains('后天')) {
    return _atDate(now.add(const Duration(days: 2)), time);
  }
  if (line.contains('明天') || line.contains('明日')) {
    return _atDate(now.add(const Duration(days: 1)), time);
  }
  if (line.contains('今天') || line.contains('今日')) {
    return _atDate(now, time);
  }

  final week = RegExp(r'(?:(本|下|这)\s*周|周|星期)\s*([一二三四五六日天])').firstMatch(line);
  if (week != null) {
    final target = _weekdayOf(week.group(2)!);
    if (target != null) {
      final delta = target - now.weekday;
      final offset = week.group(1) == '下'
          ? delta + 7
          : (delta < 0 ? delta + 7 : delta);
      return _atDate(now.add(Duration(days: offset)), time);
    }
  }

  return null;
}

DateTime? _parseTime(String line) {
  final match = RegExp(r'(\d{1,2})[:：](\d{2})').firstMatch(line);
  if (match == null) return null;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) return null;
  return DateTime(2000, 1, 1, hour, minute);
}

DateTime _at(int year, int month, int day, DateTime? time) {
  return DateTime(
    year,
    month,
    day,
    time?.hour ?? 23,
    time?.minute ?? 59,
  );
}

DateTime _atDate(DateTime date, DateTime? time) {
  return _at(date.year, date.month, date.day, time);
}

int? _weekdayOf(String char) {
  const map = {
    '一': 1,
    '二': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6,
    '日': 7,
    '天': 7,
  };
  return map[char];
}

String _cleanTitle(String line, DateTime now) {
  var text = line;
  text = text.replaceFirst(RegExp(r'^\s*\d+[\.、\)]\s*'), '');
  text = text.replaceAll(RegExp(r'20\d{2}[-/.]\d{1,2}[-/.]\d{1,2}'), '');
  text = text.replaceAll(RegExp(r'\d{1,2}月\d{1,2}日?'), '');
  text = text.replaceAll(RegExp(r'(今天|今日|明天|明日|后天)'), '');
  text = text.replaceAll(RegExp(r'(本|下|这)\s*周\s*[一二三四五六日天]'), '');
  text = text.replaceAll(RegExp(r'\d{1,2}[:：]\d{2}'), '');
  text = text.replaceAll(RegExp(r'^(前|之前|截止|于)\s*'), '');
  text = text.replaceAll(RegExp(r'^[，,。；;、\s]+'), '');
  text = text.replaceAll(RegExp(r'[，,。；;、\s]+$'), '');
  if (text.length > 24) text = '${text.substring(0, 24)}…';
  return text.trim();
}

Owner? _matchOwner(String line, List<Owner> owners) {
  for (final owner in owners) {
    final name = owner.name.trim();
    if (name.length < 2) continue;
    if (line.contains(name)) return owner;
  }
  return null;
}

OwnerKind _guessKind(String line) {
  if (RegExp(r'学习通|超星|MOOC|慕课|智慧树|学堂在线').hasMatch(line)) {
    return OwnerKind.onlineCourse;
  }
  if (RegExp(r'学生会|团委|部门').hasMatch(line)) return OwnerKind.studentUnion;
  if (RegExp(r'社团|社联|协会').hasMatch(line)) return OwnerKind.club;
  if (RegExp(r'作业|考试|课程|老师|上课|实验|课设|论文').hasMatch(line)) {
    return OwnerKind.course;
  }
  return OwnerKind.personal;
}

List<String> _materials(String line) {
  const keywords = [
    '文件',
    '报告',
    '论文',
    '作业',
    'PPT',
    'ppt',
    '海报',
    '照片',
    '截图',
    '纸质',
    '电子版',
    '表格',
    '申请表',
    'PDF',
    'Excel',
    'Word',
  ];
  final found = <String>{};
  for (final keyword in keywords) {
    if (line.contains(keyword)) found.add(keyword);
  }
  return List.unmodifiable(found);
}
