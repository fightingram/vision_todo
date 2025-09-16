import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Future<void> promptNavigateToDetail(
  BuildContext context, {
  required String label, // 夢 / 目標 / TODO
  required String title,
  required String route,
  Object? extra,
}) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('$labelを作成しました'),
      content: Text('「$title」の詳細画面に移動しますか？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('あとで'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('移動'),
        ),
      ],
    ),
  );
  if (go == true && context.mounted) {
    context.push(route, extra: extra);
  }
}

