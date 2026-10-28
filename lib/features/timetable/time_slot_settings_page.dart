import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'model/course.dart';
import 'model/time_slot.dart';
import 'model/timetable_config.dart';
import 'model/timetable_data.dart';
import 'time_slot_plan.dart';
import 'timetable_providers.dart';
import 'timetable_time.dart';
import 'widgets/time_slot_editor_sheet.dart';

class TimeSlotSettingsPage extends ConsumerStatefulWidget {
  const TimeSlotSettingsPage({super.key});

  @override
  ConsumerState<TimeSlotSettingsPage> createState() =>
      _TimeSlotSettingsPageState();
}

class _TimeSlotSettingsPageState extends ConsumerState<TimeSlotSettingsPage> {
  late TimetableConfig _config;
  late List<TimeSlot> _slots;
  late List<Course> _courses;
  late final TextEditingController _classDurationController;
  late final TextEditingController _breakDurationController;
  var _dirty = false;
  var _forcePop = false;

  @override
  void initState() {
    super.initState();
    final data = ref.read(timetableProvider);
    _config = data.config;
    _slots = [...data.timeSlots];
    _courses = [...data.courses];
    _classDurationController = TextEditingController(
      text: '${_config.defaultClassMinutes}',
    );
    _breakDurationController = TextEditingController(
      text: '${_config.defaultBreakMinutes}',
    );
  }

  @override
  void dispose() {
    _classDurationController.dispose();
    _breakDurationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_dirty || _forcePop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final discard = await _confirmDiscard();
        if (!mounted || discard != true) return;
        setState(() {
          _dirty = false;
          _forcePop = true;
        });
        navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('节次时间'),
          actions: [
            IconButton(
              tooltip: '新增节次',
              onPressed: _addSlot,
              icon: const Icon(Icons.add),
            ),
            IconButton(
              tooltip: '保存',
              onPressed: _dirty ? _save : null,
              icon: const Icon(Icons.save_outlined),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text('默认时长', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DurationField(
                    controller: _classDurationController,
                    label: '单节时长（分钟）',
                    onChanged: _onClassDurationChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DurationField(
                    controller: _breakDurationController,
                    label: '课间休息（分钟）',
                    onChanged: _onBreakDurationChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '新增节次时会用这两个值计算默认开始和结束时间。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text('节次列表', style: theme.textTheme.titleSmall),
                ),
                Text(
                  '共 ${_slots.length} 节',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_slots.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    '还没有节次，点击右上角 + 添加。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              for (final slot in _slots)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      child: Text(
                        '${slot.number}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    title: Text(slot.alias ?? '第 ${slot.number} 节'),
                    subtitle: Text(
                      '${formatMinuteOfDay(slot.startMinutes)} - '
                      '${formatMinuteOfDay(slot.endMinutes)}',
                    ),
                    onTap: () => _editSlot(slot),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: '编辑',
                          onPressed: () => _editSlot(slot),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                        ),
                        IconButton(
                          tooltip: '删除',
                          onPressed: () => _deleteSlot(slot),
                          icon: const Icon(Icons.delete_outline, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _restoreDefaultTimes,
              icon: const Icon(Icons.restart_alt),
              label: const Text('恢复默认节次时间'),
            ),
            const SizedBox(height: 12),
            Text(
              '删除未被课程使用的节次后，后面的节次会重新编号，'
              '相关课程会按原时间自动映射到新的节次。'
              '被课程使用的节次不能删除。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _markDirty() {
    if (_dirty) return;
    setState(() => _dirty = true);
  }

  void _onClassDurationChanged(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed <= 0 || parsed > 600) return;
    _config = _config.copyWith(defaultClassMinutes: parsed);
    _markDirty();
  }

  void _onBreakDurationChanged(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 0 || parsed > 600) return;
    _config = _config.copyWith(defaultBreakMinutes: parsed);
    _markDirty();
  }

  Future<void> _addSlot() async {
    final initial = TimeSlotPlan.buildNewSlot(slots: _slots, config: _config);
    final edited = await showTimeSlotEditorSheet(
      context,
      initial: initial,
      existing: _slots,
      isNew: true,
    );
    if (edited == null || !mounted) return;

    final result = TimeSlotPlan.add(
      slots: _slots,
      courses: _courses,
      slot: edited,
    );
    if (!result.ok) {
      _showMessage(result.error!);
      return;
    }

    setState(() {
      _slots = result.slots;
      _courses = result.courses;
      _dirty = true;
    });
  }

  Future<void> _editSlot(TimeSlot slot) async {
    final edited = await showTimeSlotEditorSheet(
      context,
      initial: slot,
      existing: _slots,
      isNew: false,
    );
    if (edited == null || !mounted) return;

    final result = TimeSlotPlan.update(slots: _slots, slot: edited);
    if (!result.ok) {
      _showMessage(result.error!);
      return;
    }

    setState(() {
      _slots = result.slots;
      _dirty = true;
    });
  }

  Future<void> _deleteSlot(TimeSlot slot) async {
    final used = TimeSlotPlan.usageCount(_courses, slot.number);
    if (used > 0) {
      _showMessage('第 ${slot.number} 节正被 $used 门课程使用，请先调整课程');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除节次'),
        content: Text('确定删除第 ${slot.number} 节吗？后面的节次会重新编号。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = TimeSlotPlan.remove(
      slots: _slots,
      courses: _courses,
      number: slot.number,
    );
    if (!result.ok) {
      _showMessage(result.error!);
      return;
    }

    setState(() {
      _slots = result.slots;
      _courses = result.courses;
      _dirty = true;
    });
  }

  Future<void> _restoreDefaultTimes() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('恢复默认节次时间'),
        content: const Text('将把现有节次的起止时间恢复为默认值，节次数量和课程不会改变。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      if (_slots.isEmpty) {
        _slots = [...defaultTimeSlots];
      } else {
        _slots = [
          for (final slot in _slots)
            if (defaultTimeSlots.any((item) => item.number == slot.number))
              defaultTimeSlots
                  .firstWhere((item) => item.number == slot.number)
                  .copyWith(alias: slot.alias)
            else
              slot,
        ];
      }
      _config = _config.copyWith(
        defaultClassMinutes: 45,
        defaultBreakMinutes: 10,
      );
      _classDurationController.text = '45';
      _breakDurationController.text = '10';
      _dirty = true;
    });
  }

  Future<void> _save() async {
    final classMinutes =
        int.tryParse(_classDurationController.text) ??
        _config.defaultClassMinutes;
    final breakMinutes =
        int.tryParse(_breakDurationController.text) ??
        _config.defaultBreakMinutes;

    if (classMinutes <= 0 || breakMinutes < 0) {
      _showMessage('默认时长必须是有效数字');
      return;
    }

    _config = _config.copyWith(
      defaultClassMinutes: classMinutes.clamp(1, 600).toInt(),
      defaultBreakMinutes: breakMinutes.clamp(0, 600).toInt(),
    );

    await ref
        .read(timetableProvider.notifier)
        .replaceSchedule(config: _config, timeSlots: _slots, courses: _courses);
    if (!mounted) return;
    setState(() {
      _dirty = false;
      _forcePop = true;
    });
    Navigator.of(context).pop();
  }

  Future<bool?> _confirmDiscard() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('放弃修改'),
        content: const Text('节次设置还没保存，确定离开吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DurationField extends StatelessWidget {
  const _DurationField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
