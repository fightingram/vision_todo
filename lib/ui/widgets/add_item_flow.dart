import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../models/dream.dart';
import '../../models/task.dart';
import '../../providers/term_providers.dart';
import '../../providers/task_providers.dart';
import '../../repositories/term_repositories.dart';

enum _AddType { dream, term, task }

class AddItemFlow {
  static Future<void> show(BuildContext context, WidgetRef ref) async {
    final type = await _selectType(context);
    if (type == null) return;

    int? selectedDreamId;
    int? selectedTermId;

    if (type == _AddType.term) {
      // Select Dream parent (or none)
      final dreams = await ref.read(dreamRepoProvider).watchAll().first;
      selectedDreamId = await _selectParent<int?>(
        context,
        title: '紐付ける夢を選択',
        items: const [null],
        itemBuilder: (v) => v == null ? 'どれにも紐付けない' : '',
        trailingItems: dreams.map((d) => d.id).toList(),
        trailingLabel: (id) => dreams.firstWhere((d) => d.id == id).title,
      );
      if (selectedDreamId == null) {
        // null is allowed (unlinked term)
      }
    } else if (type == _AddType.task) {
      // Select Term parent (or none) including both top-level and child terms
      final parents = await ref.read(termRepoProvider).watchByDream(null).first;
      final children = await ref.read(termRepoProvider).watchAllChildren().first;
      final allTerms = [...parents, ...children];
      selectedTermId = await _selectParent<int?>(
        context,
        title: '紐付ける目標を選択',
        items: const [null],
        itemBuilder: (v) => v == null ? 'どれにも紐付けない' : '',
        trailingItems: allTerms.map((t) => t.id).toList(),
        trailingLabel: (id) => allTerms.firstWhere((t) => t.id == id).title,
      );
    }

    final result = await _inputFields(context, type: type);
    if (result == null) return;

    final title = result.$1;
    final priority = result.$2;
    final dueAt = result.$3;

    switch (type) {
      case _AddType.dream:
        await ref.read(dreamRepoProvider).put(Dream(title: title, priority: priority, dueAt: dueAt));
        break;
      case _AddType.term:
        await ref.read(termRepoProvider).addTerm(
              title: title,
              dreamId: selectedDreamId,
              priority: priority,
              dueAt: dueAt,
            );
        break;
      case _AddType.task:
        await ref.read(taskRepoProvider).add(Task(title: title, priority: priority, dueAt: dueAt, shortTermId: selectedTermId));
        break;
    }
  }

  static Future<_AddType?> _selectType(BuildContext context) async {
    return showDialog<_AddType>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('何を追加しますか？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.bedtime_outlined),
                label: const Text('夢'),
                onPressed: () => Navigator.pop(context, _AddType.dream),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.flag_outlined),
                label: const Text('目標'),
                onPressed: () => Navigator.pop(context, _AddType.term),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.checklist_outlined),
                label: const Text('TODO'),
                onPressed: () => Navigator.pop(context, _AddType.task),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
        ],
      ),
    );
  }

  static Future<T?> _selectParent<T>(
    BuildContext context, {
    required String title,
    required List<T> items,
    required String Function(T) itemBuilder,
    List<T>? trailingItems,
    String Function(T)? trailingLabel,
  }) async {
    final all = <(T, String)>[
      ...items.map((e) => (e, itemBuilder(e))),
      if (trailingItems != null && trailingLabel != null)
        ...trailingItems.map((e) => (e, trailingLabel(e))),
    ];
    return showDialog<T>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(title),
        children: all.map((e) {
          final isNone = e.$1 == null;
          final child = isNone
              ? Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.6),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.link_off, color: Theme.of(context).disabledColor),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          e.$2,
                          style: TextStyle(color: Theme.of(context).disabledColor),
                        ),
                      ),
                    ],
                  ),
                )
              : Text(e.$2);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: SimpleDialogOption(
              onPressed: () => Navigator.pop(context, e.$1),
              child: child,
            ),
          );
        }).toList(),
      ),
    );
  }

  static Future<(String, int, DateTime?)?> _inputFields(
    BuildContext context, {
    required _AddType type,
  }) async {
    final titleCtrl = TextEditingController();
    int priority = 1;
    DateTime? dueAt;

    Future<void> pickDate() async {
      final picked = await showDatePicker(
        context: context,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
        initialDate: dueAt ?? DateTime.now(),
      );
      if (picked != null) dueAt = picked;
    }

    final result = await showDialog<(String, int, DateTime?)>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('詳細を入力'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'タイトル（必須）'),
                      autofocus: true,
                    ),
                    const SizedBox(height: 12),
                    const Text('優先度'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('低'),
                          selected: priority == 0,
                          onSelected: (_) => setState(() => priority = 0),
                        ),
                        ChoiceChip(
                          label: const Text('中'),
                          selected: priority == 1,
                          onSelected: (_) => setState(() => priority = 1),
                        ),
                        ChoiceChip(
                          label: const Text('高'),
                          selected: priority == 2,
                          onSelected: (_) => setState(() => priority = 2),
                        ),
                        ChoiceChip(
                          label: const Text('最優先'),
                          selected: priority == 3,
                          onSelected: (_) => setState(() => priority = 3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('期限'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('なし'),
                          selected: dueAt == null,
                          onSelected: (_) => setState(() => dueAt = null),
                        ),
                        ChoiceChip(
                          label: const Text('今日'),
                          selected: false,
                          onSelected: (_) => setState(() => dueAt = DateTime.now()),
                        ),
                        ChoiceChip(
                          label: const Text('明日'),
                          selected: false,
                          onSelected: (_) => setState(() => dueAt = DateTime.now().add(const Duration(days: 1))),
                        ),
                        ActionChip(
                          label: const Text('日付指定'),
                          onPressed: () async {
                            await pickDate();
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
              FilledButton(
                onPressed: () {
                  final title = titleCtrl.text.trim();
                  if (title.isEmpty) return;
                  Navigator.pop(context, (title, priority, dueAt));
                },
                child: const Text('作成'),
              ),
            ],
          );
        });
      },
    );

    return result;
  }
}
