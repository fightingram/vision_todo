import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:isar/isar.dart';

import '../models/dream.dart';
import '../models/long_term.dart';
import '../models/short_term.dart';
import '../providers/db_provider.dart';
import '../repositories/goal_repositories.dart';
import '../repositories/tag_repository.dart';
import '../models/tag.dart';
import '../repositories/goal_repositories.dart';

final dreamRepoProvider = Provider<DreamRepository>((ref) {
  final db = ref.read(isarServiceProvider);
  return DreamRepository(db);
});

final longTermRepoProvider = Provider<LongTermRepository>((ref) {
  final db = ref.read(isarServiceProvider);
  return LongTermRepository(db);
});

final shortTermRepoProvider = Provider<ShortTermRepository>((ref) {
  final db = ref.read(isarServiceProvider);
  return ShortTermRepository(db);
});

final dreamsProvider = StreamProvider.autoDispose<List<Dream>>((ref) {
  return ref.read(dreamRepoProvider).watchAll();
});

final longTermsByDreamProvider = StreamProvider.autoDispose.family<List<LongTerm>, int?>((ref, dreamId) {
  return ref.read(longTermRepoProvider).watchByDream(dreamId);
});

final shortTermsByLongProvider = StreamProvider.autoDispose.family<List<ShortTerm>, int?>((ref, longId) {
  return ref.read(shortTermRepoProvider).watchByLongTerm(longId);
});

// Convenience providers for all items
final allLongTermsProvider = StreamProvider.autoDispose<List<LongTerm>>((ref) {
  return ref.read(longTermRepoProvider).watchByDream(null);
});

final allShortTermsProvider = StreamProvider.autoDispose<List<ShortTerm>>((ref) {
  return ref.read(shortTermRepoProvider).watchByLongTerm(null);
});

// Tags
final tagRepoProvider = Provider<TagRepository>((ref) {
  final db = ref.read(isarServiceProvider);
  return TagRepository(db);
});

final tagsProvider = StreamProvider.autoDispose<List<Tag>>((ref) {
  return ref.read(tagRepoProvider).watchAll();
});

// Unified Goals
final unifiedGoalRepoProvider = Provider<GoalRepositoryUnified>((ref) {
  final db = ref.read(isarServiceProvider);
  return GoalRepositoryUnified(db);
});

final goalsByDreamProvider = StreamProvider.autoDispose.family<List<GoalNode>, int?>((ref, dreamId) {
  return ref.read(unifiedGoalRepoProvider).watchByDream(dreamId);
});

final goalsByParentProvider = StreamProvider.autoDispose.family<List<GoalNode>, int>((ref, parentGoalId) {
  return ref.read(unifiedGoalRepoProvider).watchChildren(parentGoalId);
});

// Goal with tags (for Maps UI without per-build DB calls)
final longTermWithTagsProvider =
    StreamProvider.autoDispose.family<GoalWithTags?, int>((ref, id) {
  return ref.read(longTermRepoProvider).watchWithTags(id);
});
