import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/dream.dart';
import '../../models/task.dart';
import '../../providers/term_providers.dart';
import '../../providers/task_providers.dart';
import '../widgets/memo_editor.dart';
import '../widgets/navigation_utils.dart';

final _includeArchivedProvider =
    StateProvider.autoDispose.family<bool, int>((ref, dreamId) => false);

class DreamDetailPage extends ConsumerWidget {
  const DreamDetailPage({super.key, required this.dreamId, required this.initialTitle});
  final int dreamId;
  final String initialTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dreams = ref.watch(dreamsProvider).value ?? const <Dream>[];
    final dream = dreams.where((d) => d.id == dreamId).cast<Dream?>().firstOrNull;
    final includeArchived = ref.watch(_includeArchivedProvider(dreamId));
    final termsAsync =
        ref.watch(termsByDreamWithArchivedProvider((dreamId, includeArchived)));
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
          return const Color(0xFFE25555);
        case 2:
          return const Color(0xFFE8A13A);
        case 1:
          return const Color(0xFF2B6BE4);
        default:
          return const Color(0xFF5E6672);
      }
    }

    String dueLabel(DateTime? d) {
      if (d == null) return 'なし';
      return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail'),
        actions: [
          IconButton(
            tooltip: 'タイトルを編集',
            icon: const Icon(Icons.edit),
            onPressed: dream == null
                ? null
                : () async {
                    final newTitle = await _askTitle(
                      context,
                      'タイトルを編集',
                      initial: dream.title,
                      okLabel: '保存',
                    );
                    if (newTitle == null || newTitle.isEmpty || newTitle == dream.title) return;
                    final updated = Dream(
                      id: dream.id,
                      title: newTitle,
                      priority: dream.priority,
                      dueAt: dream.dueAt,
                      color: dream.color,
                      archived: dream.archived,
                    )
                      ..createdAt = dream.createdAt
                      ..updatedAt = DateTime.now();
                    await ref.read(dreamRepoProvider).put(updated);
                  },
          ),
          IconButton(
            tooltip: 'Termを追加',
            icon: const Icon(Icons.add),
            onPressed: () async {
              final title = await _askTitle(context, 'Termを追加');
              if (title == null || title.isEmpty) return;
              final id = await ref.read(termRepoProvider).addTerm(title: title, dreamId: dreamId);
              if (!context.mounted) return;
              await promptNavigateToDetail(
                context,
                label: '目標',
                title: title,
                route: '/todo/term/$id',
                extra: title,
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'delete') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('削除確認'),
                    content: const Text('この夢を削除しますか？この操作は元に戻せません。'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('キャンセル')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('削除')),
                    ],
                  ),
                );
                if (ok == true) {
                  await ref.read(dreamRepoProvider).delete(dreamId);
                  if (context.mounted) Navigator.of(context).pop();
                }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'delete', child: Text('削除')),
            ],
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
                          icon: Icon(
                            dream.archived
                                ? Icons.undo
                                : Icons.emoji_events_outlined,
                          ),
                          label: Text(dream.archived ? '未達成に戻す' : '達成'),
                          onPressed: () async {
                            final updated = Dream(
                              id: dream.id,
                              title: dream.title,
                              priority: dream.priority,
                              dueAt: dream.dueAt,
                              color: dream.color,
                              archived: !dream.archived,
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
                            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.35)),
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
          // Filter row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                label: const Text('達成済みも表示'),
                selected: includeArchived,
                onSelected: (v) =>
                    ref.read(_includeArchivedProvider(dreamId).notifier).state = v,
              ),
            ),
          ),
          Expanded(
            child: termsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('読み込みエラー: $e')),
              data: (terms) {
                return ListView.builder(
                  itemCount: terms.isEmpty ? (dream != null ? 1 : 0) : terms.length + (dream != null ? 1 : 0),
                  itemBuilder: (context, i) {
                    // If there are terms, last item is memo editor; if none, show empty text then memo.
                    final hasDream = dream != null;
                    if (terms.isEmpty) {
                      if (hasDream && i == 0) {
                        return Column(
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Text('Termはありません'),
                            ),
                            MemoEditor(type: 'dream', id: dreamId),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    }
                    final isMemo = hasDream && i == terms.length;
                    if (isMemo) {
                      return MemoEditor(type: 'dream', id: dreamId);
                    }
                    final t = terms[i];
                    final count = tasks.where((x) => x.shortTermId == t.id).length;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: const Icon(Icons.flag_outlined),
                        title: Text(t.title),
                        subtitle: Text('TODO ${count} 件'),
                        trailing: t.archived
                            ? Chip(
                                label: const Text('達成済み'),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              )
                            : null,
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

Future<String?> _askTitle(BuildContext context, String title, {String? initial, String okLabel = '追加'}) async {
  final controller = TextEditingController(text: initial ?? '');
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
        FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: Text(okLabel)),
      ],
    ),
  );
}
