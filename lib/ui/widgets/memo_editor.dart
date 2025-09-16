import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../providers/memo_provider.dart';

class MemoEditor extends ConsumerStatefulWidget {
  const MemoEditor({super.key, required this.type, required this.id, this.title = 'メモ'});
  final String type; // 'dream' | 'term' | 'task'
  final int id;
  final String title;

  @override
  ConsumerState<MemoEditor> createState() => _MemoEditorState();
}

class _MemoEditorState extends ConsumerState<MemoEditor> {
  final _controller = TextEditingController();
  bool _loadedOnce = false;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memoAsync = ref.watch(memoTextProvider((widget.type, widget.id)));
    memoAsync.whenData((value) {
      if (!_loadedOnce) {
        _controller.text = value ?? '';
        _loadedOnce = true;
      }
    });

    Future<void> save() async {
      setState(() => _saving = true);
      await ref
          .read(memoServiceProvider)
          .saveMemo(widget.type, widget.id, _controller.text);
      if (mounted) {
        ref.invalidate(memoTextProvider((widget.type, widget.id)));
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メモを保存しました')),
        );
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sticky_note_2_outlined, size: 18),
                const SizedBox(width: 6),
                Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: _saving ? null : save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('保存'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              minLines: 3,
              maxLines: null,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '自由にメモを残せます',
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _saving
                    ? null
                    : () {
                        _controller.clear();
                      },
                child: const Text('クリア'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

