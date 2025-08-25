import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/dream.dart';
import '../providers/db_provider.dart';
import '../repositories/term_repositories.dart';
import '../repositories/tag_repository.dart';
import '../models/tag.dart';

final dreamRepoProvider = Provider<DreamRepository>((ref) {
  final db = ref.read(isarServiceProvider);
  return DreamRepository(db);
});

final dreamsProvider = StreamProvider.autoDispose<List<Dream>>((ref) {
  return ref.read(dreamRepoProvider).watchAll();
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

final termsByDreamProvider =
    StreamProvider.autoDispose.family<List<Term>, int?>((ref, dreamId) {
  return ref.read(termRepoProvider).watchByDream(dreamId);
});

final termsByParentProvider =
    StreamProvider.autoDispose.family<List<Term>, int>((ref, parentId) {
  return ref.read(termRepoProvider).watchChildren(parentId);
});

// Unified: all top-level terms
final allTopTermsProvider = StreamProvider.autoDispose<List<Term>>((ref) {
  return ref.read(termRepoProvider).watchByDream(null);
});

// Unified: all child terms
final allChildTermsProvider = StreamProvider.autoDispose<List<Term>>((ref) {
  return ref.read(termRepoProvider).watchAllChildren();
});

// Unified: watch a term with tags by id
final termWithTagsProvider =
    StreamProvider.autoDispose.family<TermWithTags?, int>((ref, id) {
  return ref.read(termRepoProvider).watchWithTags(id);
});
