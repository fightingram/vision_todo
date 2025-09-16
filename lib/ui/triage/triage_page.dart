import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../models/task.dart';
import '../../models/short_term.dart';
import '../../models/long_term.dart';
import '../../models/dream.dart';
import '../../providers/db_provider.dart';
import '../../models/tag.dart';
import '../../providers/settings_provider.dart';
import '../../providers/task_providers.dart';
import '../../utils/date_utils.dart' as du;
import '../../providers/triage_provider.dart';

class TriagePage extends ConsumerStatefulWidget {
  const TriagePage({super.key});

  @override
  ConsumerState<TriagePage> createState() => _TriagePageState();
}

class _TriagePageState extends ConsumerState<TriagePage> {
  late List<Task> _queue;

  @override
  void initState() {
    super.initState();
    _queue = [];
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(triageTasksProvider);
    final repo = ref.read(taskRepoProvider);
    final weekStart = du.startOfWeek(DateTime.now(), ref.read(settingsProvider).weekStart);

    // Refresh queue when provider updates
    _queue = List.of(tasks);

    void decide(Task t, bool planned) async {
      await repo.setTriageDecision(t, weekStart, planned: planned);
      setState(() {
        _queue.removeWhere((e) => e.id == t.id);
      });
      if (_queue.isEmpty && mounted) Navigator.of(context).pop();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('今週の仕分け'),
        actions: [
          TextButton(
            onPressed: () {
              // Skip for this week's session: suppress auto-open for current week
              ref.read(triageSkipWeekProvider.notifier).state = weekStart;
              Navigator.of(context).pop();
            },
            child: const Text('スキップ'),
          )
        ],
      ),
      body: _queue.isEmpty
          ? const Center(child: Text('今週の仕分けは完了しました'))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Expanded(
                    child: Dismissible(
                      key: ValueKey(_queue.first.id),
                      direction: DismissDirection.horizontal,
                      onDismissed: (dir) {
                        decide(_queue.first, dir == DismissDirection.endToStart ? false : true);
                      },
                      background: Container(
                        color: Colors.green.withOpacity(0.3),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: const Row(children: [Icon(Icons.arrow_right_alt, size: 32), Text(' 今週やる')]),
                      ),
                      secondaryBackground: Container(
                        color: Colors.red.withOpacity(0.3),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text(' やらない'), Icon(Icons.close)]),
                      ),
                      child: _TriageCard(task: _queue.first),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => decide(_queue.first, false),
                          icon: const Icon(Icons.close),
                          label: const Text('やらない'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => decide(_queue.first, true),
                          icon: const Icon(Icons.check),
                          label: const Text('今週やる'),
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

class _TriageCard extends ConsumerWidget {
  const _TriageCard({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isar = ref.read(isarServiceProvider).isar;

    Future<(ShortTerm?, LongTerm?, Dream?, List<Tag>)> loadChain() async {
      ShortTerm? st;
      LongTerm? lt;
      Dream? dr;
      List<Tag> tags = const [];
      final id = task.shortTermId;
      if (id != null) {
        // First, try interpreting as ShortTerm id
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
          // Fallback: interpret as LongTerm id
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

    String statusLabel(TaskStatus s) {
      switch (s) {
        case TaskStatus.todo:
          return '未着手';
        case TaskStatus.doing:
          return '進行中';
        case TaskStatus.done:
          return '完了';
      }
    }

    Color statusColor(TaskStatus s, BuildContext context) {
      switch (s) {
        case TaskStatus.todo:
          return Theme.of(context).disabledColor;
        case TaskStatus.doing:
          return Colors.blue;
        case TaskStatus.done:
          return Colors.green;
      }
    }

    String dueLabel(DateTime? d) {
      if (d == null) return 'なし';
      return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
    }

    String priorityLabel(int p) {
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

    Color priorityColor(int p, BuildContext context) {
      switch (p) {
        case 3:
          return Colors.red;
        case 2:
          return Colors.orange;
        case 1:
          return Colors.blue;
        default:
          return Theme.of(context).disabledColor;
      }
    }

    return FutureBuilder<(ShortTerm?, LongTerm?, Dream?, List<Tag>)>(
      future: loadChain(),
      builder: (context, snapshot) {
        final st = snapshot.data?.$1;
        final lt = snapshot.data?.$2;
        final dr = snapshot.data?.$3;
        final tags = snapshot.data?.$4 ?? const <Tag>[];
        return Card(
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (st != null || lt != null || dr != null) ...[
                  const SizedBox(height: 4),
                  if (dr != null)
                    Row(children: [const Icon(Icons.lightbulb_outline, size: 16), const SizedBox(width: 6), Flexible(child: Text('夢: ${dr.title}'))]),
                  if (lt != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [const Icon(Icons.emoji_flags_outlined, size: 16), const SizedBox(width: 6), Flexible(child: Text('長期目標: ${lt.title}'))]),
                  ],
                  if (st != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [const Icon(Icons.flag_outlined, size: 16), const SizedBox(width: 6), Flexible(child: Text('短期目標: ${st.title}'))]),
                  ],
                  const SizedBox(height: 8),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(
                      label: Text(statusLabel(task.status)),
                      backgroundColor: statusColor(task.status, context).withOpacity(0.1),
                      side: BorderSide(color: statusColor(task.status, context).withOpacity(0.3)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: priorityColor(task.priority, context).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: priorityColor(task.priority, context).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flag, size: 16, color: priorityColor(task.priority, context)),
                          const SizedBox(width: 6),
                          Text('優先度: ${priorityLabel(task.priority)}'),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.event, size: 16),
                          const SizedBox(width: 6),
                          Text('期限: ${dueLabel(task.dueAt)}'),
                        ],
                      ),
                    ),
                  ],
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
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
    );
  }
}
