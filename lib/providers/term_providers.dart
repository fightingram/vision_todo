import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:isar/isar.dart';

import '../models/dream.dart';
import '../models/long_term.dart';
import '../models/short_term.dart';
import '../providers/db_provider.dart';
import '../repositories/term_repositories.dart';
import '../repositories/tag_repository.dart';
import '../models/tag.dart';
import '../repositories/term_repositories.dart';

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

// Unified Terms
final termRepoProvider = Provider<TermRepository>((ref) {
  final db = ref.read(isarServiceProvider);
  return TermRepository(db);
});

final termsByDreamProvider = StreamProvider.autoDispose.family<List<Term>, int?>((ref, dreamId) {
  return ref.read(termRepoProvider).watchByDream(dreamId);
});

final termsByParentProvider = StreamProvider.autoDispose.family<List<Term>, int>((ref, parentGoalId) {
  return ref.read(termRepoProvider).watchChildren(parentGoalId);
});

// Unified: all top-level terms (formerly LongTerm)
final allTopTermsProvider = StreamProvider.autoDispose<List<Term>>((ref) {
  return ref.read(termRepoProvider).watchByDream(null);
});

// Unified: all child terms (formerly ShortTerm under any parent)
final allChildTermsProvider = StreamProvider.autoDispose<List<Term>>((ref) {
  return ref.read(termRepoProvider).watchAllChildren();
});

// Unified: watch a term with tags by id
final termWithTagsProvider =
    StreamProvider.autoDispose.family<TermWithTags?, int>((ref, id) {
  return ref.read(termRepoProvider).watchWithTags(id);
});

// LongTerm with tags (for Maps UI without per-build DB calls)
final longTermWithTagsProvider =
    StreamProvider.autoDispose.family<GoalWithTags?, int>((ref, id) {
  return ref.read(longTermRepoProvider).watchWithTags(id);
});

final shortTermWithTagsProvider =
    StreamProvider.autoDispose.family<ShortTermWithTags?, int>((ref, id) {
  return ref.read(shortTermRepoProvider).watchWithTags(id);
});
