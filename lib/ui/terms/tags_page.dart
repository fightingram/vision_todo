import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../models/tag.dart';
import '../../providers/term_providers.dart';

class TagsPage extends ConsumerWidget {
  const TagsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('タグ管理'),
        actions: [
          IconButton(
            onPressed: () async {
              final tag = await _showNewTagDialog(context);
              if (tag != null) {
                await ref.read(tagRepoProvider).put(tag);
              }
            },
            tooltip: 'タグを追加',
            icon: const Icon(Icons.add),
          )
        ],
      ),
      body: tagsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('読み込みエラー: $e')),
        data: (tags) => ListView.builder(
          itemCount: tags.length,
          itemBuilder: (context, i) => _TagTile(tag: tags[i]),
        ),
      ),
    );
  }
}

class _TagTile extends ConsumerWidget {
  const _TagTile({required this.tag});
  final Tag tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: Color(tag.color)),
      title: Text(tag.name),
      trailing: IconButton(
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('削除しますか？'),
              content: Text('タグ "${tag.name}" を削除します。'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除')),
              ],
            ),
          );
          if (ok == true) {
            await ref.read(tagRepoProvider).delete(tag.id);
          }
        },
        icon: const Icon(Icons.delete_outline),
      ),
      onTap: () async {
        final updated = await _showEditTagDialog(context, tag);
        if (updated != null) {
          await ref.read(tagRepoProvider).put(updated);
        }
      },
    );
  }
}

Future<Tag?> _showNewTagDialog(BuildContext context) async {
  final nameCtrl = TextEditingController();
  int color = 0xFF9E9E9E;
  return showDialog<Tag>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('新しいタグ'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: '名前'),
            autofocus: true,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('色：'),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  final picked = await _pickColor(context, color);
                  if (picked != null) {
                    color = picked;
                    // ignore: use_build_context_synchronously
                    (context as Element).markNeedsBuild();
                  }
                },
                child: CircleAvatar(backgroundColor: Color(color), radius: 12),
              ),
            ],
          )
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
        FilledButton(
          onPressed: () {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) {
              Navigator.pop(context);
              return;
            }
            Navigator.pop(context, Tag(name: name, color: color));
          },
          child: const Text('作成'),
        ),
      ],
    ),
  );
}

Future<Tag?> _showEditTagDialog(BuildContext context, Tag tag) async {
  final nameCtrl = TextEditingController(text: tag.name);
  int color = tag.color;
  return showDialog<Tag>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('タグを編集'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: '名前'),
            autofocus: true,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('色：'),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  final picked = await _pickColor(context, color);
                  if (picked != null) {
                    color = picked;
                    // ignore: use_build_context_synchronously
                    (context as Element).markNeedsBuild();
                  }
                },
                child: CircleAvatar(backgroundColor: Color(color), radius: 12),
              ),
            ],
          )
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
        FilledButton(
          onPressed: () {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) {
              Navigator.pop(context);
              return;
            }
            final updated = Tag(id: tag.id, name: name, color: color)
              ..createdAt = tag.createdAt
              ..updatedAt = DateTime.now();
            Navigator.pop(context, updated);
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
}

Future<int?> _pickColor(BuildContext context, int initial) async {
  final colors = <int>[
    0xFFEF9A9A,
    0xFFF48FB1,
    0xFFCE93D8,
    0xFFB39DDB,
    0xFF90CAF9,
    0xFFA5D6A7,
    0xFFFFF59D,
    0xFFFFCC80,
    0xFFB0BEC5,
    0xFF80CBC4,
  ];
  int selected = initial;
  return showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('色を選択'),
      content: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: colors
            .map((c) => GestureDetector(
                  onTap: () => Navigator.pop(context, c),
                  child: CircleAvatar(
                    backgroundColor: Color(c),
                    child: selected == c ? const Icon(Icons.check, color: Colors.white) : null,
                  ),
                ))
            .toList(),
      ),
    ),
  );
}
