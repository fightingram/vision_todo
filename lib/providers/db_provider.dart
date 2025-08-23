import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:isar/isar.dart';

import '../models/short_term.dart';
import '../services/isar_service.dart';

final isarServiceProvider = Provider<IsarService>((ref) {
  return IsarService();
});

final isarInitProvider = FutureProvider<void>((ref) async {
  final service = ref.read(isarServiceProvider);
  await service.init();
});
