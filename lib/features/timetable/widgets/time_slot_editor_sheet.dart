import 'package:flutter/material.dart';

import '../model/time_slot.dart';
import '../timetable_time.dart';
import '../time_slot_plan.dart';

Future<TimeSlot?> showTimeSlotEditorSheet(
  BuildContext context, {
  required TimeSlot initial,
  required List<TimeSlot> existing,
  required bool isNew,
}) {
  return showModalBottomSheet<TimeSlot>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      final available = media.size.height - media.viewInsets.bottom;

      return Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: available * 0.92),
          child: _TimeSlotEditorSheet(
            initial: initial,
            existing: existing,
            isNew: isNew,
          ),
        ),
      );
    },
  );
}

class _TimeSlotEditorSheet extends StatefulWidget {
  const _TimeSlotEditorSheet({
    required this.initial,
    required this.existing,
    required this.isNew,
  });

  final TimeSlot initial;
  final List<TimeSlot> existing;
  final bool isNew;

  @override
  State<_TimeSlotEditorSheet> createState() => _TimeSlotEditorSheetState();
}

class _TimeSlotEditorSheetState extends State<_TimeSlotEditorSheet> {
  late int _startMinutes;
  late int _endMinutes;
  late final TextEditingController _aliasController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startMinutes = widget.initial.startMinutes;
    _endMinutes = widget.initial.endMinutes;
    _aliasController = TextEditingController(text: widget.initial.alias ?? '');
  }

  @override
  void dispose() {
    _aliasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.isNew ? '新增时间段' : '编辑时段 ${widget.initial.number}',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: '关闭',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _TimeField(
                        label: '开始时间',
                        minutes: _startMinutes,
                        onChanged: (value) =>
                            setState(() => _startMinutes = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TimeField(
                        label: '结束时间',
                        minutes: _endMinutes,
                        onChanged: (value) =>
                            setState(() => _endMinutes = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _aliasController,
                  maxLength: 5,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: '时间段别名（可选）',
                    hintText: '例如：早自习',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '时长 ${_durationMinutes()} 分钟',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
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
                  child: Text(widget.isNew ? '添加' : '保存'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  int _durationMinutes() {
    final value = _endMinutes - _startMinutes;
    return value < 0 ? 0 : value;
  }

  void _save() {
    final alias = _aliasController.text.trim();
    final slot = TimeSlot(
      number: widget.initial.number,
      startMinutes: _startMinutes,
      endMinutes: _endMinutes,
      alias: alias.isEmpty ? null : alias,
    );
    final error = TimeSlotPlan.validate(
      slot: slot,
      existing: widget.existing,
      editingNumber: widget.isNew ? null : widget.initial.number,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    Navigator.of(context).pop(slot);
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.minutes,
    required this.onChanged,
  });

  final String label;
  final int minutes;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 360;
    final diameter = compact ? 84.0 : 96.0;

    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: minutes ~/ 60,
                  minute: minutes % 60,
                ),
                helpText: label,
              );
              if (picked == null) return;
              onChanged(picked.hour * 60 + picked.minute);
            },
            child: SizedBox(
              width: diameter,
              height: diameter,
              child: Center(
                child: Text(
                  formatMinuteOfDay(minutes),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
