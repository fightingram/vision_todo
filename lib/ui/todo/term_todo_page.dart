import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../models/task.dart';
import '../../models/tag.dart';
import '../../repositories/term_repositories.dart';
import '../../providers/task_providers.dart';
import '../../providers/term_providers.dart';
import '../widgets/task_tile.dart';

class TermTodoPage extends ConsumerWidget {
  const TermTodoPage({super.key, required this.goalId, required this.goalTitle});
  final int goalId;
  final String goalTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(taskRepoProvider);
    final goalWithTags = ref.watch(termWithTagsProvider(goalId));
    final shortsAsync = ref.watch(termsByParentProvider(goalId));

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

    String dueLabel(DateTime? d) {
      if (d == null) return 'なし';
      return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(goalWithTags.asData?.value?.item.title ?? goalTitle),
        actions: [
          IconButton(
            tooltip: 'TODOを追加',
            icon: const Icon(Icons.add_task),
            onPressed: () async {
              final shorts = shortsAsync.value ?? const <Term>[];
              final title = await _askTitle(context, 'TODOを追加');
              if (title == null || title.isEmpty) return;

              int? targetId;
              if (shorts.isEmpty) {
                // 子Termがない場合は、このTerm直下に作成
                targetId = goalId;
              } else {
                // このTerm直下 も選択肢に含めて選ばせる
                targetId = await _pickTargetTerm(
                  context,
                  currentTermId: goalId,
                  currentTermTitle: goalTitle,
                  children: shorts,
                );
              }
              if (targetId == null) return;
              await repo.add(Task(title: title, shortTermId: targetId));
            },
          ),
        ],
      ),
      body: goalWithTags.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('読み込みエラー: $e')),
        data: (gwt) {
          if (gwt == null) {
            return const Center(child: Text('Termが見つかりません'));
          }
          final item = gwt.item;
          final tags = gwt.tags;
          return Column(
            children: [
              // Header: goal details
              Card(
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: priorityColor(item.priority, context).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: priorityColor(item.priority, context).withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.flag, size: 16, color: priorityColor(item.priority, context)),
                                const SizedBox(width: 6),
                                Text('優先度: ${priorityLabel(item.priority)}'),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.event, size: 16),
                                const SizedBox(width: 6),
                                Text('期限: ${dueLabel(item.dueAt)}'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (tags.isNotEmpty) ...[
                        const Text('タグ'),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: -8,
                          children: tags
                              .map((t) => Chip(
                                    label: Text(t.name),
                                    visualDensity: VisualDensity.compact,
                                  ))
                              .toList(),
                        ),
                      ] else ...[
                        Text('タグ: なし', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                child: shortsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('読み込みエラー: $e')),
                  data: (shorts) {
                    // このTerm直下と子Term直下の両方を表示対象にする
                    final shortIds = shorts.map((s) => s.id).toSet()..add(goalId);
                    final tasks = ref.watch(tasksStreamProvider).value ?? const <Task>[];
                    final items = tasks
                        .where((t) => t.shortTermId != null && shortIds.contains(t.shortTermId))
                        .toList();
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
              ),
            ],
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

Future<int?> _pickTargetTerm(BuildContext context, {required int currentTermId, required String currentTermTitle, required List<Term> children}) async {
  int? selectedId = currentTermId;
  return showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('作成先を選択'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<int>(
              value: currentTermId,
              groupValue: selectedId,
              onChanged: (v) => selectedId = v,
              title: Text('このTermに作成（$currentTermTitle）'),
            ),
            const Divider(height: 12),
            ...children.map((s) => RadioListTile<int>(
                  value: s.id,
                  groupValue: selectedId,
                  onChanged: (v) => selectedId = v,
                  title: Text('子Term: ${s.title}'),
                )),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, selectedId);
          },
          child: const Text('選択'),
        ),
      ],
    ),
  );
}
