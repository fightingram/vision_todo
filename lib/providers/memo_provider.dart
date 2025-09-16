import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../services/memo_service.dart';

final memoServiceProvider = Provider<MemoService>((ref) => MemoService());

final memoTextProvider = FutureProvider.family<String?, (String, int)>((ref, key) async {
  final (type, id) = key;
  return ref.read(memoServiceProvider).getMemo(type, id);
});

