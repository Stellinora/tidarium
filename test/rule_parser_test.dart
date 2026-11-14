import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/features/import/rule_parser.dart';
import 'package:tidarium/features/owners/model/owner.dart';

void main() {
  final now = DateTime(2026, 11, 13, 10); // 周五

  test('解析绝对日期与网课类型', () {
    final drafts = parseRules(
      text: '各位同学：11月20日前提交英语计划书到学习通，记得交 PDF。',
      now: now,
    );

    expect(drafts, hasLength(1));
    final draft = drafts.single;
    expect(draft.dueAt, DateTime(2026, 11, 20, 23, 59));
    expect(draft.kind, OwnerKind.onlineCourse);
    expect(draft.materials, contains('PDF'));
  });

  test('解析明天与具体时刻', () {
    final drafts = parseRules(
      text: '明天 18:30 学生会开会，带笔记本。',
      now: now,
    );

    expect(drafts, hasLength(1));
    expect(drafts.single.dueAt, DateTime(2026, 11, 14, 18, 30));
    expect(drafts.single.kind, OwnerKind.studentUnion);
  });

  test('匹配归属名并带上 ownerId', () {
    final owners = [
      Owner(
        id: 'o_club',
        profileId: 'p1',
        kind: OwnerKind.club,
        name: 'ACM 集训队',
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final drafts = parseRules(
      text: 'ACM 集训队周五晚上训练，记得签到。',
      now: now,
      owners: owners,
    );

    expect(drafts, hasLength(1));
    expect(drafts.single.ownerId, 'o_club');
    expect(drafts.single.kind, OwnerKind.club);
  });

  test('没有时间的任务标待补', () {
    final drafts = parseRules(text: '记得提交实验报告', now: now);
    expect(drafts, hasLength(1));
    expect(drafts.single.dueAt, isNull);
    expect(drafts.single.warnings, contains('时间待补'));
  });

  test('忽略称呼与无动作的行', () {
    final drafts = parseRules(
      text: '各位同学请注意\n今天天气不错\n',
      now: now,
    );
    expect(drafts, isEmpty);
  });
}

