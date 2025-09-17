import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../models/task.dart';
import '../../models/tag.dart';
import '../../repositories/term_repositories.dart';
import '../../providers/task_providers.dart';
import '../../providers/term_providers.dart';
import '../widgets/task_tile.dart';
import 'package:go_router/go_router.dart';
import '../widgets/memo_editor.dart';
import '../widgets/navigation_utils.dart';

class TermTodoPage extends ConsumerWidget {
  const TermTodoPage(
      {super.key, required this.termId, required this.termTitle});
  final int termId;
  final String termTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(taskRepoProvider);
    final termWithTags = ref.watch(termWithTagsProvider(termId));
    final shortsAsync = ref.watch(termsByParentProvider(termId));

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
            onPressed: () async {
              final gwt = termWithTags.asData?.value;
              final item = gwt?.item;
              if (item == null) return;
              final newTitle = await _askTitle(
                context,
                'タイトルを編集',
                initial: item.title,
                okLabel: '保存',
              );
              if (newTitle == null || newTitle.isEmpty || newTitle == item.title) return;
              final updated = Term(
                id: item.id,
                title: newTitle,
                parentId: item.parentId,
                dreamId: item.dreamId,
                priority: item.priority,
                dueAt: item.dueAt,
                archived: item.archived,
                color: item.color,
              );
              await ref.read(termRepoProvider).updateTerm(updated, gwt?.tags ?? const []);
            },
          ),
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
                targetId = termId;
              } else {
                // このTerm直下 も選択肢に含めて選ばせる
                targetId = await _pickTargetTerm(
                  context,
                  currentTermId: termId,
                  currentTermTitle: termTitle,
                  children: shorts,
                );
              }
              if (targetId == null) return;
              final t = await repo.add(Task(title: title, shortTermId: targetId));
              await promptNavigateToDetail(
                context,
                label: 'TODO',
                title: t.title,
                route: '/todo/task/${t.id}',
                extra: t.title,
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
                    content: const Text('この目標を削除しますか？この操作は元に戻せません。'),
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
                  final termRepo = ref.read(termRepoProvider);
                  final t = await termRepo.getById(termId);
                  if (t != null) {
                    await termRepo.deleteTerm(t);
                    if (context.mounted) Navigator.of(context).pop();
                  }
                }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'delete', child: Text('削除')),
            ],
          ),
        ],
      ),
      body: termWithTags.when(
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
              // Header: term details
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                      if (item.dreamId != null)
                        FutureBuilder(
                          future: ref.read(dreamRepoProvider).getById(item.dreamId!),
                          builder: (context, snap) {
                            final d = snap.data;
                            if (d == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: InkWell(
                                onTap: () => context.push('/maps/dream/${d.id}', extra: d.title),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.bedtime_outlined, size: 16),
                                    const SizedBox(width: 6),
                                    Text('夢: ${d.title}'),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            icon: Icon(item.archived
                                ? Icons.undo
                                : Icons.emoji_events_outlined),
                            label: Text(item.archived ? '未達成に戻す' : '達成'),
                            onPressed: () async {
                              await ref
                                  .read(termRepoProvider)
                                  .archiveTerm(item, archived: !item.archived);
                            },
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: priorityColor(item.priority, context)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: priorityColor(item.priority, context)
                                      .withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.flag,
                                    size: 16,
                                    color:
                                        priorityColor(item.priority, context)),
                                const SizedBox(width: 6),
                                Text('優先度: ${priorityLabel(item.priority)}'),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Theme.of(context)
                                      .dividerColor
                                      .withOpacity(0.35)),
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
                        Text('タグ: なし',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                child: shortsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('読み込みエラー: $e')),
                  data: (shorts) {
                    // このTerm直下と子Term直下の両方を表示対象にする
                    final shortIds = shorts.map((s) => s.id).toSet()
                      ..add(termId);
                    final tasks =
                        ref.watch(tasksStreamProvider).value ?? const <Task>[];
                    final items = tasks
                        .where((t) =>
                            t.shortTermId != null &&
                            shortIds.contains(t.shortTermId))
                        .toList();
                    final children = <Widget>[];
                    if (items.isEmpty) {
                      children.add(const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Center(child: Text('TODOはありません')),
                      ));
                    } else {
                      children.addAll(items.map((t) => Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: TaskTile(
                              task: t,
                              showCheckbox: false,
                              showEditMenu: false,
                            ),
                          )));
                    }
                    children.add(MemoEditor(type: 'term', id: termId));
                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                      children: children,
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

Future<String?> _askTitle(BuildContext context, String title, {String? initial, String okLabel = '追加'}) async {
  final controller = TextEditingController(text: initial ?? '');
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
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル')),
        FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(okLabel)),
      ],
    ),
  );
}

Future<int?> _pickTargetTerm(BuildContext context,
    {required int currentTermId,
    required String currentTermTitle,
    required List<Term> children}) async {
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
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル')),
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
