import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../owners/model/owner.dart';
import '../../owners/owner_providers.dart';
import '../../tags/model/tag.dart';
import '../../tags/tag_providers.dart';
import '../../timetable/timetable_providers.dart';
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

class _TodoEditorSheet extends ConsumerStatefulWidget {
  const _TodoEditorSheet({this.initial});

  final TodoItem? initial;

  @override
  ConsumerState<_TodoEditorSheet> createState() => _TodoEditorSheetState();
}

class _TodoEditorSheetState extends ConsumerState<_TodoEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late final TextEditingController _sourceController;
  late DateTime _dueAt;
  String? _titleError;

  late String _profileId;
  String _ownerId = '';
  List<Owner> _owners = const [];
  List<Tag> _tags = const [];
  final Set<String> _selectedTagIds = <String>{};
  bool _loadingMeta = true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _noteController = TextEditingController(text: initial?.note ?? '');
    _sourceController = TextEditingController(text: initial?.source ?? '');
    final now = DateTime.now();
    _dueAt = initial?.dueAt ?? DateTime(now.year, now.month, now.day, 23, 59);
    _profileId = initial?.profileId.isNotEmpty == true
        ? initial!.profileId
        : ref.read(timetableLibraryProvider).activeId;
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    final ownerStore = ref.read(ownerStoreProvider);
    final tagStore = ref.read(tagStoreProvider);

    final owners = await ownerStore.all(_profileId);
    final tags = await tagStore.all(_profileId);

    var ownerId = widget.initial?.ownerId ?? '';
    if (ownerId.isEmpty || !owners.any((owner) => owner.id == ownerId)) {
      final fallback = await ownerStore.findDefault(_profileId);
      ownerId = fallback?.id ?? (owners.isEmpty ? '' : owners.first.id);
    }

    var tagIds = <String>{};
    final initial = widget.initial;
    if (initial != null) {
      tagIds = (await tagStore.tagIdsOf(initial.id)).toSet();
    }

    if (!mounted) return;
    setState(() {
      _owners = owners;
      _tags = tags;
      _ownerId = ownerId;
      _selectedTagIds
        ..clear()
        ..addAll(tagIds);
      _loadingMeta = false;
    });
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

  Future<void> _createTag() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('新建标签'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '例如：作业'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;

    final tag = await ref
        .read(tagStoreProvider)
        .upsertByName(_profileId, name.trim());
    final tags = await ref.read(tagStoreProvider).all(_profileId);
    if (!mounted) return;
    setState(() {
      _tags = tags;
      _selectedTagIds.add(tag.id);
    });
  }

  Future<void> _save() async {
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
      profileId: _profileId,
      ownerId: _ownerId,
    );

    await ref
        .read(tagStoreProvider)
        .setTodoTags(item.id, _selectedTagIds, profileId: _profileId);

    if (!mounted) return;
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
            if (_loadingMeta)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              )
            else ...[
              DropdownButtonFormField<String>(
                initialValue: _ownerId.isEmpty ? null : _ownerId,
                decoration: const InputDecoration(
                  labelText: '归属',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final owner in _owners)
                    DropdownMenuItem(
                      value: owner.id,
                      child: Text(
                        '${owner.name} · ${owner.kind.label}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _ownerId = value);
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('标签', style: theme.textTheme.labelLarge),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final tag in _tags)
                    FilterChip(
                      label: Text(tag.name),
                      selected: _selectedTagIds.contains(tag.id),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedTagIds.add(tag.id);
                          } else {
                            _selectedTagIds.remove(tag.id);
                          }
                        });
                      },
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text('新建'),
                    onPressed: _createTag,
                  ),
                ],
              ),
            ],
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
