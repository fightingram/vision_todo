import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../models/task.dart';
import '../../providers/task_providers.dart';
import '../../providers/db_provider.dart';
import '../../models/short_term.dart';
import '../../models/long_term.dart';
import '../../models/dream.dart';
import '../../models/tag.dart';
import 'package:go_router/go_router.dart';
import '../widgets/memo_editor.dart';

class TaskDetailPage extends ConsumerWidget {
  const TaskDetailPage({super.key, required this.taskId, this.initialTitle});
  final int taskId;
  final String? initialTitle;

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

  Color _priorityColor(int p, BuildContext context) {
    switch (p) {
      case 3:
        return const Color(0xFFE25555);
      case 2:
        return const Color(0xFFE8A13A);
      case 1:
        return const Color(0xFF2B6BE4);
      default:
        return const Color(0xFF5E6672);
    }
  }

  String _dateLabel(DateTime? d) {
    if (d == null) return 'なし';
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
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
        return const Color(0xFF5E6672);
      case TaskStatus.doing:
        return const Color(0xFF2B6BE4);
      case TaskStatus.done:
        return const Color(0xFF3CB371);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskStream = ref.watch(taskByIdProvider(taskId));
    final repo = ref.read(taskRepoProvider);
    final isar = ref.read(isarServiceProvider).isar;

    return Scaffold(
      appBar: AppBar(
        title: Text(taskStream.asData?.value?.title ?? initialTitle ?? 'TODO'),
        actions: [
          IconButton(
            tooltip: '編集',
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final task = taskStream.asData?.value;
              if (task == null) return;
              final updated = await showDialog<Task>(
                context: context,
                builder: (_) => _EditTaskDialog(initial: task),
              );
              if (updated != null) {
                await repo.update(updated);
              }
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              final task = taskStream.asData?.value;
              if (task == null) return;
              if (v == 'delete') {
                await repo.delete(task.id);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'delete', child: Text('削除')),
            ],
          ),
        ],
      ),
      body: taskStream.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('読み込みエラー: $e')),
        data: (task) {
          if (task == null) {
            return const Center(child: Text('TODOが見つかりません'));
          }
          Future<(ShortTerm?, LongTerm?, Dream?, List<Tag>)> loadChain(Task task) async {
            ShortTerm? st;
            LongTerm? lt;
            Dream? dr;
            List<Tag> tags = const [];
            final id = task.shortTermId;
            if (id != null) {
              // Try as ShortTerm first
              st = await isar.shortTerms.get(id);
              if (st != null) {
                await st.tags.load();
                tags = st.tags.toList();
                if (st.longTermId != null) {
                  lt = await isar.longTerms.get(st.longTermId!);
                  if (lt?.dreamId != null) {
                    dr = await isar.dreams.get(lt!.dreamId!);
                  }
                }
              } else {
                // Fallback: treat as LongTerm id
                lt = await isar.longTerms.get(id);
                if (lt != null) {
                  await lt.tags.load();
                  tags = lt.tags.toList();
                  if (lt.dreamId != null) {
                    dr = await isar.dreams.get(lt.dreamId!);
                  }
                }
              }
            }
            return (st, lt, dr, tags);
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.title, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('ステータス:'),
                          ChoiceChip(
                            label: const Text('未着手'),
                            selected: task.status == TaskStatus.todo,
                            onSelected: (_) => repo.setStatus(task, TaskStatus.todo),
                          ),
                          ChoiceChip(
                            label: const Text('進行中'),
                            selected: task.status == TaskStatus.doing,
                            onSelected: (_) => repo.setStatus(task, TaskStatus.doing),
                          ),
                          ChoiceChip(
                            label: const Text('完了'),
                            selected: task.status == TaskStatus.done,
                            onSelected: (_) => repo.setStatus(task, TaskStatus.done),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _priorityColor(task.priority, context).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _priorityColor(task.priority, context).withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.flag, size: 16, color: _priorityColor(task.priority, context)),
                                const SizedBox(width: 6),
                                Text('優先度: ${_priorityLabel(task.priority)}'),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.35)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.event, size: 16),
                                const SizedBox(width: 6),
                                Text('期限: ${_dateLabel(task.dueAt)}'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              FutureBuilder<(ShortTerm?, LongTerm?, Dream?, List<Tag>)>(
                future: loadChain(task),
                builder: (context, snapshot) {
                  final st = snapshot.data?.$1;
                  final lt = snapshot.data?.$2;
                  final dr = snapshot.data?.$3;
                  final tags = snapshot.data?.$4 ?? const <Tag>[];
                  if (st == null && lt == null && dr == null && tags.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (dr != null)
                            InkWell(
                              onTap: () => context.push('/maps/dream/${dr.id}', extra: dr.title),
                              child: Row(children: [const Icon(Icons.lightbulb_outline, size: 16), const SizedBox(width: 6), Flexible(child: Text('夢: ${dr.title}'))]),
                            ),
                          if (lt != null) ...[
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () => context.push('/todo/term/${lt.id}', extra: lt.title),
                              child: Row(children: [const Icon(Icons.emoji_flags_outlined, size: 16), const SizedBox(width: 6), Flexible(child: Text('長期目標: ${lt.title}'))]),
                            ),
                          ],
                          if (st != null) ...[
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () => context.push('/todo/term/${st.id}', extra: st.title),
                              child: Row(children: [const Icon(Icons.flag_outlined, size: 16), const SizedBox(width: 6), Flexible(child: Text('短期目標: ${st.title}'))]),
                            ),
                          ],
                          if (tags.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: tags
                                  .map((t) => Chip(
                                        label: Text(t.name),
                                        backgroundColor: Color(t.color).withOpacity(0.15),
                                        side: BorderSide(color: Color(t.color).withOpacity(0.4)),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
              Card(
                child: ListTile(
                  title: const Text('作成日時'),
                  trailing: Text(_dateLabel(task.createdAt)),
                ),
              ),
              Card(
                child: ListTile(
                  title: const Text('更新日時'),
                  trailing: Text(_dateLabel(task.updatedAt)),
                ),
              ),
              Card(
                child: ListTile(
                  title: const Text('現在のステータス'),
                  trailing: Chip(
                    label: Text(_statusLabel(task.status)),
                    backgroundColor: _statusColor(task.status, context).withOpacity(0.1),
                    side: BorderSide(color: _statusColor(task.status, context).withOpacity(0.3)),
                  ),
                ),
              ),
              MemoEditor(type: 'task', id: task.id),
            ],
          );
        },
      ),
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
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'タイトル'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              const Text('期限'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                      label: const Text('なし'),
                      selected: _dueAt == null,
                      onSelected: (_) => setState(() => _dueAt = null)),
                  ChoiceChip(
                      label: const Text('今日'),
                      selected: false,
                      onSelected: (_) =>
                          setState(() => _dueAt = DateTime.now())),
                  ChoiceChip(
                      label: const Text('明日'),
                      selected: false,
                      onSelected: (_) => setState(() => _dueAt =
                          DateTime.now().add(const Duration(days: 1)))),
                  ActionChip(label: const Text('日付指定'), onPressed: pickDate),
                ],
              ),
              const SizedBox(height: 12),
              const Text('優先度'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                      label: const Text('低'),
                      selected: _priority == 0,
                      onSelected: (_) => setState(() => _priority = 0)),
                  ChoiceChip(
                      label: const Text('中'),
                      selected: _priority == 1,
                      onSelected: (_) => setState(() => _priority = 1)),
                  ChoiceChip(
                      label: const Text('高'),
                      selected: _priority == 2,
                      onSelected: (_) => setState(() => _priority = 2)),
                  ChoiceChip(
                      label: const Text('最優先'),
                      selected: _priority == 3,
                      onSelected: (_) => setState(() => _priority = 3)),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル')),
        FilledButton(
          onPressed: () {
            final updated = Task(
              id: widget.initial.id,
              title: _title.text.trim().isEmpty
                  ? widget.initial.title
                  : _title.text.trim(),
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
