import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:isar/isar.dart';

import '../../models/task.dart';
import '../../providers/task_providers.dart';

class TaskTile extends ConsumerWidget {
  const TaskTile({
    super.key,
    required this.task,
    this.showCheckbox = true,
    this.showEditMenu = true,
  });
  final Task task;
  final bool showCheckbox;
  final bool showEditMenu;

  Color _priorityColor(int p) {
    switch (p) {
      case 3:
        return const Color(0xFFE25555); // danger
      case 2:
        return const Color(0xFFE8A13A); // warning
      case 1:
        return const Color(0xFF2B6BE4); // brand
      default:
        return const Color(0xFF5E6672); // secondary
    }
  }

  String _priorityLabel(int p) {
    switch (p) {
      case 3:
        return '最優先';
      case 2:
        return '高';
      case 1:
        return '中';
      default:
        return '低';
    }
  }

  String _statusLabel(TaskStatus s) {
    switch (s) {
      case TaskStatus.todo:
        return '未着手';
      case TaskStatus.doing:
        return '進行中';
      case TaskStatus.done:
        return '完了';
    }
  }

  Color _statusColor(TaskStatus s, BuildContext context) {
    switch (s) {
      case TaskStatus.todo:
        return const Color(0xFF5E6672); // secondary
      case TaskStatus.doing:
        return const Color(0xFF2B6BE4); // brand
      case TaskStatus.done:
        return const Color(0xFF3CB371); // success
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(taskRepoProvider);
    return ListTile(
      leading: showCheckbox
          ? Checkbox(
              value: task.status == TaskStatus.done,
              onChanged: (_) => repo.toggleDone(task),
            )
          : null,
      title: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Chip(
            label: Text(_statusLabel(task.status)),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
            backgroundColor: _statusColor(task.status, context).withOpacity(0.1),
            side: BorderSide(color: _statusColor(task.status, context).withOpacity(0.3)),
          ),
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: _priorityColor(task.priority),
              shape: BoxShape.circle,
            ),
          ),
          Text(_priorityLabel(task.priority)),
          if (task.dueAt != null)
            Chip(
              label: Text(DateFormat('M/d').format(task.dueAt!)),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
              side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.35)),
            ),
        ],
      ),
      trailing: showEditMenu
          ? PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'edit') {
                  final updated = await showDialog<Task>(
                    context: context,
                    builder: (_) => _EditTaskDialog(initial: task),
                  );
                  if (updated != null) {
                    await repo.update(updated);
                  }
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('編集')),
              ],
            )
          : null,
      onTap: () {
        context.push('/todo/task/${task.id}', extra: task.title);
      },
    );
  }
}

class _EditTaskDialog extends StatefulWidget {
  const _EditTaskDialog({required this.initial});
  final Task initial;

  @override
  State<_EditTaskDialog> createState() => _EditTaskDialogState();
}

class _EditTaskDialogState extends State<_EditTaskDialog> {
  late TextEditingController _title;
  late int _priority;
  DateTime? _dueAt;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial.title);
    _priority = widget.initial.priority;
    _dueAt = widget.initial.dueAt;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Future<void> pickDate() async {
      final picked = await showDatePicker(
        context: context,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
        initialDate: _dueAt ?? DateTime.now(),
      );
      if (picked != null) setState(() => _dueAt = picked);
    }

    return AlertDialog(
      title: const Text('TODOを編集'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: _title, decoration: const InputDecoration(labelText: 'タイトル'), autofocus: true),
              const SizedBox(height: 12),
              const Text('期限'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(label: const Text('なし'), selected: _dueAt == null, onSelected: (_) => setState(() => _dueAt = null)),
                  ChoiceChip(label: const Text('今日'), selected: false, onSelected: (_) => setState(() => _dueAt = DateTime.now())),
                  ChoiceChip(label: const Text('明日'), selected: false, onSelected: (_) => setState(() => _dueAt = DateTime.now().add(const Duration(days: 1)))),
                  ActionChip(label: const Text('日付指定'), onPressed: pickDate),
                ],
              ),
              const SizedBox(height: 12),
              const Text('優先度'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(label: const Text('低'), selected: _priority == 0, onSelected: (_) => setState(() => _priority = 0)),
                  ChoiceChip(label: const Text('中'), selected: _priority == 1, onSelected: (_) => setState(() => _priority = 1)),
                  ChoiceChip(label: const Text('高'), selected: _priority == 2, onSelected: (_) => setState(() => _priority = 2)),
                  ChoiceChip(label: const Text('最優先'), selected: _priority == 3, onSelected: (_) => setState(() => _priority = 3)),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
        FilledButton(
          onPressed: () {
            final updated = Task(
              id: widget.initial.id,
              title: _title.text.trim().isEmpty ? widget.initial.title : _title.text.trim(),
              priority: _priority,
              dueAt: _dueAt,
              shortTermId: widget.initial.shortTermId,
              archived: widget.initial.archived,
              status: widget.initial.status,
              doneAt: widget.initial.doneAt,
            )
              ..createdAt = widget.initial.createdAt
              ..updatedAt = DateTime.now();
            Navigator.pop(context, updated);
          },
          child: const Text('保存'),
        )
      ],
    );
  }
}
