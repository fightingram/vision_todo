import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../models/task.dart';
import '../../providers/task_providers.dart';
import '../widgets/task_tile.dart';

class GoalTodoPage extends ConsumerWidget {
  const GoalTodoPage({super.key, required this.goalId, required this.goalTitle});
  final int goalId;
  final String goalTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(taskRepoProvider);
    final stream = repo.watchByGoal(goalId);
    return Scaffold(
      appBar: AppBar(
        title: Text(goalTitle),
        actions: [
          IconButton(
            tooltip: 'TODOを追加',
            icon: const Icon(Icons.add_task),
            onPressed: () async {
              final title = await _askTitle(context, 'TODOを追加');
              if (title != null && title.isNotEmpty) {
                await repo.add(Task(title: title, shortTermId: goalId));
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Task>>(
        stream: stream,
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <Task>[];
          if (items.isEmpty) {
            return const Center(child: Text('TODOはありません'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) => Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: TaskTile(task: items[i]),
            ),
          );
        },
      ),
    );
  }
}

Future<String?> _askTitle(BuildContext context, String title) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'タイトル'),
        onSubmitted: (_) => Navigator.of(context).pop(controller.text.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('追加')),
      ],
    ),
  );
}

