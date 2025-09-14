import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/dream.dart';
import '../../models/task.dart';
import '../../providers/term_providers.dart';
import '../../providers/task_providers.dart';

class DreamDetailPage extends ConsumerWidget {
  const DreamDetailPage({super.key, required this.dreamId, required this.initialTitle});
  final int dreamId;
  final String initialTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dreams = ref.watch(dreamsProvider).value ?? const <Dream>[];
    final dream = dreams.where((d) => d.id == dreamId).cast<Dream?>().firstOrNull;
    final termsAsync = ref.watch(termsByDreamProvider(dreamId));
    final tasks = ref.watch(tasksStreamProvider).value ?? const <Task>[];

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
        title: Text(dream?.title ?? initialTitle),
        actions: [
          IconButton(
            tooltip: 'Termを追加',
            icon: const Icon(Icons.add),
            onPressed: () async {
              final title = await _askTitle(context, 'Termを追加');
              if (title == null || title.isEmpty) return;
              await ref.read(termRepoProvider).addTerm(title: title, dreamId: dreamId);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Header: dream details (参考: Term画面)
          if (dream != null)
            Card(
              margin: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dream.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.emoji_events_outlined),
                          label: Text(dream.archived ? '達成済み' : '達成'),
                          onPressed: dream.archived
                              ? null
                              : () async {
                                  final updated = Dream(
                                    id: dream.id,
                                    title: dream.title,
                                    priority: dream.priority,
                                    dueAt: dream.dueAt,
                                    color: dream.color,
                                    archived: true,
                                  )
                                    ..createdAt = dream.createdAt
                                    ..updatedAt = DateTime.now();
                                  await ref.read(dreamRepoProvider).put(updated);
                                },
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: priorityColor(dream.priority, context).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: priorityColor(dream.priority, context).withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.flag, size: 16, color: priorityColor(dream.priority, context)),
                              const SizedBox(width: 6),
                              Text('優先度: ${priorityLabel(dream.priority)}'),
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
                              Text('期限: ${dueLabel(dream.dueAt)}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: termsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('読み込みエラー: $e')),
              data: (terms) {
                if (terms.isEmpty) {
                  return const Center(child: Text('Termはありません'));
                }
                return ListView.builder(
                  itemCount: terms.length,
                  itemBuilder: (context, i) {
                    final t = terms[i];
                    final count = tasks.where((x) => x.shortTermId == t.id).length;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: const Icon(Icons.flag_outlined),
                        title: Text(t.title),
                        subtitle: Text('TODO ${count} 件'),
                        onTap: () {
                          // Navigate to Term detail (TODO list)
                          context.push('/todo/term/${t.id}', extra: t.title);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

extension _IterableX<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
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
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('追加')),
      ],
    ),
  );
}
