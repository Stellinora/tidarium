/// 三段式提示词：角色、字段与格式、规则与反例。
/// 固定文案便于在项目文档里原样引用。
String buildOcrPrompt() {
  return '''
你是一个 OCR 工具。
任务：把图片里所有文字按原顺序转录出来。
规则：
1. 只输出文字本身，不要总结、不要解释、不要补全。
2. 保留换行；看不清的字用 □ 代替。
3. 不要输出图片里没有的内容。
''';
}

String buildExtractPrompt({
  required String text,
  required DateTime today,
  required String profileName,
}) {
  final todayText =
      '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

  return '''
你是校园事务助手，负责把群通知整理成待办草稿。

今天是 $todayText，当前课表：$profileName。

输入文本：
"""
$text
"""

请输出 JSON 对象，格式如下：
{
  "items": [
    {
      "title": "待办标题，去掉时间和客套话，不超过 20 字",
      "type": "course | onlineCourse | studentUnion | club | personal | other",
      "dueAt": "YYYY-MM-DDTHH:mm:ss 或 null",
      "materials": ["需要提交的材料，没有就空数组"],
      "source": "谁发的或哪个群，可留空",
      "confidence": 0.0 到 1.0 的数字
    }
  ]
}

规则（必须遵守）：
1. 只提取明确出现的事项。文本里没有的事项不要编造。
2. dueAt 只能来自文本中明确写出的日期或时间；没有写就填 null，不要猜测。
   - 「11月20日」且未写时刻 → 当天 23:59:00
   - 「第13-14周」这类相对周次无法换算 → 填 null
   - 可以换算「今天/明天/后天」，但必须以 $todayText 为基准
3. 一条通知里有多个事项时，拆成多条。
4. 归属按语义判断：课程作业 → course；学习通/MOOC 等网课 → onlineCourse；学生会 → studentUnion；社团 → club；其余 → personal 或 other。
5. 不要输出 JSON 以外的任何文字。

反例（不要这样）：
- 文本没写时间，却填了今天 23:59 → 错，应填 null
- 把「请大家注意」当成一条待办 → 错，应忽略
- 把一条通知里的两个截止时间合并成一条 → 错，应拆开
''';
}
