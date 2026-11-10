import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../model/todo_item.dart';

Future<TodoItem?> showTodoEditorSheet(
  BuildContext context, {
  TodoItem? initial,
}) {
  return showModalBottomSheet<TodoItem>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _TodoEditorSheet(initial: initial),
  );
}

class _TodoEditorSheet extends StatefulWidget {
  const _TodoEditorSheet({this.initial});

  final TodoItem? initial;

  @override
  State<_TodoEditorSheet> createState() => _TodoEditorSheetState();
}

class _TodoEditorSheetState extends State<_TodoEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late final TextEditingController _sourceController;
  late DateTime _dueAt;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _noteController = TextEditingController(text: initial?.note ?? '');
    _sourceController = TextEditingController(text: initial?.source ?? '');
    final now = DateTime.now();
    _dueAt = initial?.dueAt ?? DateTime(now.year, now.month, now.day, 23, 59);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _pickDueAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: '选择截止日期',
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt),
      helpText: '选择截止时间',
    );
    if (!mounted) return;

    setState(() {
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _dueAt.hour,
        time?.minute ?? _dueAt.minute,
      );
    });
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = '请输入待办标题');
      return;
    }

    final now = DateTime.now();
    final initial = widget.initial;
    final item = TodoItem(
      id: initial?.id ?? newTodoId(),
      title: title,
      note: _noteController.text.trim(),
      dueAt: _dueAt,
      source: _sourceController.text.trim(),
      completed: initial?.completed ?? false,
      completedAt: initial?.completedAt,
      createdAt: initial?.createdAt ?? now,
      updatedAt: now,
    );
    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initial == null ? '添加待办' : '编辑待办',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              autofocus: widget.initial == null,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: '标题',
                hintText: '例如：提交高数作业',
                errorText: _titleError,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_titleError != null) {
                  setState(() => _titleError = null);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sourceController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '布置人 / 来源',
                hintText: '例如：高数老师',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '备注',
                hintText: '可选',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('截止时间'),
              subtitle: Text(
                DateFormat('yyyy年M月d日 HH:mm').format(_dueAt),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickDueAt,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: Text(widget.initial == null ? '添加' : '保存'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
