import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../model/todo_item.dart';

class TodoSection extends StatefulWidget {
  const TodoSection({
    super.key,
    required this.title,
    required this.todos,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.showOverdue = false,
  });

  final String title;
  final List<TodoItem> todos;
  final ValueChanged<TodoItem> onToggle;
  final ValueChanged<TodoItem> onEdit;
  final ValueChanged<TodoItem> onDelete;
  final bool showOverdue;

  @override
  State<TodoSection> createState() => _TodoSectionState();
}

class _TodoSectionState extends State<TodoSection> {
  var _showCompleted = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = widget.todos.where((todo) => !todo.completed).toList();
    final completed = widget.todos.where((todo) => todo.completed).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
          child: Row(
            children: [
              Text(
                widget.title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (active.isNotEmpty)
                Text(
                  '${active.length} 项未完成',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (active.isEmpty && completed.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Text(
              '暂无待办',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else ...[
          for (final todo in active)
            _TodoTile(
              todo: todo,
              showOverdue: widget.showOverdue,
              onToggle: () => widget.onToggle(todo),
              onEdit: () => widget.onEdit(todo),
              onDelete: () => widget.onDelete(todo),
            ),
          if (completed.isNotEmpty) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => setState(() => _showCompleted = !_showCompleted),
              icon: Icon(
                _showCompleted ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              label: Text(
                _showCompleted
                    ? '收起已完成'
                    : '已完成 ${completed.length} 项',
              ),
            ),
            if (_showCompleted)
              for (final todo in completed)
                _TodoTile(
                  todo: todo,
                  showOverdue: false,
                  onToggle: () => widget.onToggle(todo),
                  onEdit: () => widget.onEdit(todo),
                  onDelete: () => widget.onDelete(todo),
                ),
          ],
        ],
      ],
    );
  }
}

class _TodoTile extends StatelessWidget {
  const _TodoTile({
    required this.todo,
    required this.showOverdue,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final TodoItem todo;
  final bool showOverdue;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overdue = showOverdue && todo.isOverdueAt(DateTime.now());
    final dueLabel = DateFormat('M月d日 HH:mm').format(todo.dueAt);
    final subtitle = [
      if (todo.source.isNotEmpty) todo.source,
      '截止 $dueLabel',
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
        leading: Checkbox(
          value: todo.completed,
          onChanged: (_) => onToggle(),
        ),
        title: Text(
          todo.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            decoration: todo.completed ? TextDecoration.lineThrough : null,
            color: todo.completed
                ? theme.colorScheme.onSurfaceVariant
                : overdue
                ? theme.colorScheme.error
                : null,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: overdue
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: PopupMenuButton<String>(
          tooltip: '更多',
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('编辑')),
            PopupMenuItem(value: 'delete', child: Text('删除')),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}
