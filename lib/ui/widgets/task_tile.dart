import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:isar/isar.dart';

import '../../models/task.dart';
import '../../providers/task_providers.dart';

class TaskTile extends ConsumerWidget {
  const TaskTile({super.key, required this.task});
  final Task task;

  Color _priorityColor(int p) {
    switch (p) {
      case 3:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 1:
        return Colors.blue;
      default:
        return Colors.grey;
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(taskRepoProvider);
    return ListTile(
      leading: Checkbox(
        value: task.status == TaskStatus.done,
        onChanged: (_) => repo.toggleDone(task),
      ),
      title: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
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
              side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2)),
            ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          switch (v) {
            case 'p0':
            case 'p1':
            case 'p2':
            case 'p3':
              task.priority = int.parse(v.substring(1));
              break;
            case 'today':
              task.dueAt = DateTime.now();
              break;
            case 'tomorrow':
              task.dueAt = DateTime.now().add(const Duration(days: 1));
              break;
            case 'week':
              final now = DateTime.now();
              final weekday = now.weekday;
              final toAdd = 7 - weekday; // end of week (Sun)
              task.dueAt = DateTime(now.year, now.month, now.day).add(Duration(days: toAdd));
              break;
            case 'date':
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                initialDate: task.dueAt ?? DateTime.now(),
              );
              if (picked != null) task.dueAt = picked;
              break;
            case 'none':
              task.dueAt = null;
              break;
            case 'delete':
              await repo.delete(task.id);
              return;
          }
          await repo.update(task);
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'p3', child: Text('優先度: 最優先')),
          const PopupMenuItem(value: 'p2', child: Text('優先度: 高')),
          const PopupMenuItem(value: 'p1', child: Text('優先度: 中')),
          const PopupMenuItem(value: 'p0', child: Text('優先度: 低')),
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'today', child: Text('期限: 今日')),
          const PopupMenuItem(value: 'tomorrow', child: Text('期限: 明日')),
          const PopupMenuItem(value: 'week', child: Text('期限: 今週')),
          const PopupMenuItem(value: 'date', child: Text('期限: 日付指定')),
          const PopupMenuItem(value: 'none', child: Text('期限: なし')),
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'delete', child: Text('削除')),
        ],
      ),
    );
  }
}
