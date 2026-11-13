import '../owners/model/owner.dart';

/// OCR 提示词：尽量短，减少输入 token 与生成时的额外解释。
String buildOcrPrompt() {
  return '逐行转录图片中的文字，保留换行与数字，看不清写 □。'
      '只输出文字，不要解释。';
}

/// 抽取提示词：把归属清单交给模型，要求只返回标准 JSON。
String buildExtractPrompt({
  required String text,
  required DateTime today,
  required String profileName,
  required List<Owner> owners,
}) {
  final todayText =
      '${today.year}-${today.month.toString().padLeft(2, '0')}-'
      '${today.day.toString().padLeft(2, '0')}';
  const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  final weekdayText = '周${weekdays[today.weekday - 1]}';

  final ownerLines = owners.isEmpty
      ? '（无可用归属，ownerId 一律填 null）'
      : owners
            .map(
              (owner) => owner.isOnlineCourse
                  ? '{"id":"${owner.id}","name":"${owner.name}",'
                        '"kind":"${owner.kind.name}","platform":"${owner.platform?.name ?? ''}"}'
                  : '{"id":"${owner.id}","name":"${owner.name}",'
                        '"kind":"${owner.kind.name}"}',
            )
            .join('\n');

  return '''
把下面的校园通知整理成待办，只输出 JSON。

今天是 $todayText（$weekdayText），当前课表：$profileName。

可用归属（ownerId 只能从这里选，选不到填 null，不许编造）：
$ownerLines

通知原文：
"""
$text
"""

输出格式：
{"items":[{"title":"","ownerId":null,"dueAt":null,"materials":[],"source":"","confidence":0.0}]}

规则：
1. 只提取明确出现的事项，不要编造。
2. dueAt 写成 YYYY-MM-DDTHH:mm:ss；没写时刻按当天 23:59:00。
   - 「11月20日」「11月20日前」→ 当年的 11-20T23:59:00
   - 「明天」「后天」「本周五」→ 以今天 $todayText 为基准换算
   - 「第13-14周」无法换算 → 填 null
   - 原文完全没提时间 → 填 null，不要猜
3. 一条通知有多个事项时拆成多条。
4. title 去掉时间与客套话，不超过 20 字。
5. 反例：原文没写时间却填了今天 23:59 —— 错，应填 null。
''';
}

