import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../models/task.dart';
import '../../models/short_term.dart';
import '../../models/long_term.dart';
import '../../models/dream.dart';
import '../../providers/db_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/task_providers.dart';
import '../../utils/date_utils.dart' as du;

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
      appBar: AppBar(title: const Text('今週の仕分け')),
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

    Future<(ShortTerm?, LongTerm?, Dream?)> loadChain() async {
      ShortTerm? st;
      LongTerm? lt;
      Dream? dr;
      if (task.shortTermId != null) {
        st = await isar.shortTerms.get(task.shortTermId!);
        if (st?.longTermId != null) {
          lt = await isar.longTerms.get(st!.longTermId!);
          if (lt?.dreamId != null) {
            dr = await isar.dreams.get(lt!.dreamId!);
          }
        }
      }
      return (st, lt, dr);
    }

    return FutureBuilder<(ShortTerm?, LongTerm?, Dream?)>(
      future: loadChain(),
      builder: (context, snapshot) {
        final st = snapshot.data?.$1;
        final lt = snapshot.data?.$2;
        final dr = snapshot.data?.$3;
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
                if (task.dueAt != null)
                  Row(children: [const Icon(Icons.event, size: 16), const SizedBox(width: 6), Text('期限: ${task.dueAt!.month}/${task.dueAt!.day}')]),
                const SizedBox(height: 8),
                Row(children: [const Icon(Icons.priority_high_outlined, size: 16), const SizedBox(width: 6), Text('優先度: ${task.priority}')]),
              ],
            ),
          ),
        );
      },
    );
  }
}
