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
                  widget.isNew ? '新增节次' : '编辑第 ${widget.initial.number} 节',
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
                    labelText: '节次别名（可选）',
                    hintText: '例如：早自习',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${formatMinuteOfDay(_startMinutes)} - '
                    '${formatMinuteOfDay(_endMinutes)}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
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
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.centerLeft,
      ),
      onPressed: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
          helpText: label,
        );
        if (picked == null) return;
        onChanged(picked.hour * 60 + picked.minute);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(
            formatMinuteOfDay(minutes),
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
