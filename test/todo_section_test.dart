import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/features/todos/model/todo_item.dart';
import 'package:tidarium/features/todos/widgets/todo_section.dart';
import 'package:tidarium/ui/theme.dart';

TodoItem _todo(String id, String title, DateTime dueAt) {
  final now = DateTime.now();
  return TodoItem(
    id: id,
    title: title,
    dueAt: dueAt,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _wrap(List<TodoItem> todos) {
  return MaterialApp(
    theme: buildTidariumTheme(Brightness.light),
    home: Scaffold(
      body: SingleChildScrollView(
        child: TodoSection(
          title: '待办事项',
          todos: todos,
          showOverdue: true,
          onToggle: (_) {},
          onEdit: (_) {},
          onDelete: (_) {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('逾期与临期分别打标', (tester) async {
    final now = DateTime.now();
    final todos = [
      _todo('overdue', '过期的作业', now.subtract(const Duration(hours: 2))),
      _todo('soon', '两小时后截止', now.add(const Duration(hours: 2))),
      _todo('later', '下周的任务', now.add(const Duration(days: 5))),
    ];

    await tester.pumpWidget(_wrap(todos));

    expect(find.textContaining('已逾期'), findsOneWidget);
    expect(find.textContaining('临期'), findsOneWidget);
    expect(find.text('下周的任务'), findsOneWidget);
  });

  testWidgets('逾期项排在前面', (tester) async {
    final now = DateTime.now();
    final todos = [
      _todo('later', '后天的任务', now.add(const Duration(days: 2))),
      _todo('overdue', '过期的作业', now.subtract(const Duration(days: 1))),
    ];

    await tester.pumpWidget(_wrap(todos));

    final overdueY = tester.getTopLeft(find.text('过期的作业')).dy;
    final laterY = tester.getTopLeft(find.text('后天的任务')).dy;
    expect(overdueY, lessThan(laterY));
  });
}
