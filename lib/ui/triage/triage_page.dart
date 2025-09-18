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
import '../theme/design_tokens.dart';

class TriagePage extends ConsumerStatefulWidget {
  const TriagePage({super.key});

  @override
  ConsumerState<TriagePage> createState() => _TriagePageState();
}

class _TriagePageState extends ConsumerState<TriagePage> {
  late List<Task> _queue;
  int? _initialCount;

  @override
  void initState() {
    super.initState();
    _queue = [];
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(triageTasksProvider);
    final repo = ref.read(taskRepoProvider);
    final weekStart =
        du.startOfWeek(DateTime.now(), ref.read(settingsProvider).weekStart);

    // Refresh queue when provider updates
    _queue = List.of(tasks);
    _initialCount ??= _queue.length;

    void decide(Task t, bool planned) async {
      await repo.setTriageDecision(t, weekStart, planned: planned);
      setState(() {
        _queue.removeWhere((e) => e.id == t.id);
      });
      if (_queue.isEmpty && mounted) Navigator.of(context).pop();
    }

    String weekLabel(DateTime start) {
      final end = du.endOfWeek(start, ref.read(settingsProvider).weekStart);
      String fmt(DateTime d) => '${d.month}/${d.day}';
      return '${fmt(start)} - ${fmt(end)}';
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header chips
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: DT.bgTint,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: DT.borderSubtle),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.event,
                                size: 16, color: DT.textSecondary),
                            const SizedBox(width: 6),
                            Text('今週: ${weekLabel(weekStart)}',
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: DT.brandPrimary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: DT.brandPrimary.withOpacity(0.3)),
                        ),
                        child: Text(
                            '残り ${_queue.length} / ${_initialCount ?? _queue.length} 件',
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Swipe hint
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: DT.bgTint,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: DT.borderSubtle),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Row(children: [
                          Text('左: やらない'),
                          SizedBox(width: 6),
                          Icon(Icons.swipe_left,
                              size: 18, color: DT.stateDanger)
                        ]),
                        Row(children: [
                          Icon(Icons.swipe_right,
                              size: 18, color: DT.stateSuccess),
                          SizedBox(width: 6),
                          Text('右: 今週やる')
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Context chain (outside of card): Dream / Goals
                  FutureBuilder<(ShortTerm?, LongTerm?, Dream?)>(
                    future: (() async {
                      ShortTerm? st;
                      LongTerm? lt;
                      Dream? dr;
                      final id = _queue.first.shortTermId;
                      final isar = ref.read(isarServiceProvider).isar;
                      if (id != null) {
                        st = await isar.shortTerms.get(id);
                        if (st != null) {
                          if (st.longTermId != null) {
                            lt = await isar.longTerms.get(st.longTermId!);
                            if (lt?.dreamId != null) {
                              dr = await isar.dreams.get(lt!.dreamId!);
                            }
                          }
                        } else {
                          lt = await isar.longTerms.get(id);
                          if (lt != null && lt.dreamId != null) {
                            dr = await isar.dreams.get(lt.dreamId!);
                          }
                        }
                      }
                      return (st, lt, dr);
                    })(),
                    builder: (context, snap) {
                      final st = snap.data?.$1;
                      final lt = snap.data?.$2;
                      final dr = snap.data?.$3;
                      if (st == null && lt == null && dr == null)
                        return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            if (dr != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.lightbulb_outline, size: 16),
                                  const SizedBox(width: 6),
                                  Text('夢: ${dr!.title}')
                                ],
                              ),
                            if (lt != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.emoji_flags_outlined,
                                      size: 16),
                                  const SizedBox(width: 6),
                                  Text('長期目標: ${lt!.title}')
                                ],
                              ),
                            if (st != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.flag_outlined, size: 16),
                                  const SizedBox(width: 6),
                                  Text('短期目標: ${st!.title}')
                                ],
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  // Card area
                  Expanded(
                    child: Dismissible(
                      key: ValueKey(_queue.first.id),
                      direction: DismissDirection.horizontal,
                      onDismissed: (dir) {
                        // 右=今週やる, 左=やらない
                        decide(
                            _queue.first, dir == DismissDirection.startToEnd);
                      },
                      background: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          heightFactor: 0.75,
                          widthFactor: 1.0,
                          child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF3CB371).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: const Color(0xFF3CB371).withOpacity(0.35)),
                        ),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: const Row(children: [
                              Icon(Icons.check_circle,
                                  size: 28, color: Color(0xFF3CB371)),
                              SizedBox(width: 8),
                              Text('今週やる')
                            ]),
                          ),
                        ),
                      ),
                      secondaryBackground: Align(
                        alignment: Alignment.centerRight,
                        child: FractionallySizedBox(
                          heightFactor: 0.75,
                          widthFactor: 1.0,
                          child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE25555).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: const Color(0xFFE25555).withOpacity(0.35)),
                        ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: const Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text('やらない'),
                                  SizedBox(width: 8),
                                  Icon(Icons.cancel,
                                      color: Color(0xFFE25555), size: 26)
                                ]),
                          ),
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.center,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: FractionallySizedBox(
                            heightFactor: 0.75,
                            alignment: Alignment.center,
                            child: _TriageCard(task: _queue.first),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Progress bar above action buttons
                  _TriageProgress(
                      total: _initialCount ?? 0, remaining: _queue.length),
                  const SizedBox(height: 8),
                  // Action buttons placed closer to card
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14)),
                          onPressed: () => decide(_queue.first, false),
                          icon: const Icon(Icons.close),
                          label: const Text('やらない'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14)),
                          onPressed: () => decide(_queue.first, true),
                          icon: const Icon(Icons.check),
                          label: const Text('今週やる'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
          return const Color(0xFF5E6672);
        case TaskStatus.doing:
          return const Color(0xFF2B6BE4);
        case TaskStatus.done:
          return const Color(0xFF3CB371);
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
          return const Color(0xFFE25555);
        case 2:
          return const Color(0xFFE8A13A);
        case 1:
          return const Color(0xFF2B6BE4);
        default:
          return const Color(0xFF5E6672);
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
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(
                      label: Text(statusLabel(task.status)),
                      backgroundColor:
                          statusColor(task.status, context).withOpacity(0.1),
                      side: BorderSide(
                          color: statusColor(task.status, context)
                              .withOpacity(0.3)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: priorityColor(task.priority, context)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: priorityColor(task.priority, context)
                                .withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flag,
                              size: 16,
                              color: priorityColor(task.priority, context)),
                          const SizedBox(width: 6),
                          Text('優先度: ${priorityLabel(task.priority)}'),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Theme.of(context)
                                .dividerColor
                                .withOpacity(0.5)),
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
                              side: BorderSide(
                                  color: Color(t.color).withOpacity(0.4)),
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

class _TriageProgress extends StatelessWidget {
  const _TriageProgress({required this.total, required this.remaining});
  final int total;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();
    final done = (total - remaining).clamp(0, total);
    final progress = done / total;
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 4,
        child: Stack(
          children: [
            Container(color: const Color(0xFFE6E2D8)),
            FractionallySizedBox(
              widthFactor: progress,
              child: Container(color: const Color(0xFF2B6BE4)),
            ),
          ],
        ),
      ),
    );
  }
}
