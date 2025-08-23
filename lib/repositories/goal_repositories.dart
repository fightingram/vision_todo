import 'package:isar/isar.dart';

import '../models/dream.dart';
import '../models/long_term.dart';
import '../models/short_term.dart';
import '../services/isar_service.dart';
import '../models/tag.dart';

class DreamRepository {
  DreamRepository(this._db);
  final IsarService _db;
  Isar get _isar => _db.isar;

  Stream<List<Dream>> watchAll({bool includeArchived = false}) {
    final q = includeArchived
        ? _isar.dreams.where().sortByCreatedAt()
        : _isar.dreams.filter().archivedEqualTo(false).sortByCreatedAt();
    return q.watch(fireImmediately: true);
  }

  Future<void> put(Dream dream) async {
    dream.updatedAt = DateTime.now();
    await _isar.writeTxn(() async => _isar.dreams.put(dream));
  }

  Future<void> delete(Id id) async {
    await _isar.writeTxn(() async => _isar.dreams.delete(id));
  }

  Future<Dream?> getById(int id) async {
    return _isar.dreams.get(id);
  }
}

// Unified Goal view model that wraps LongTerm (parent) and ShortTerm (child)
enum GoalKind { parent, child }

class GoalNode {
  GoalNode.parent(LongTerm l)
      : kind = GoalKind.parent,
        id = l.id,
        title = l.title,
        parentId = null,
        dreamId = l.dreamId,
        priority = l.priority,
        dueAt = l.dueAt,
        archived = l.archived,
        color = null;

  GoalNode.child(ShortTerm s, {required int? dreamIdOfParent})
      : kind = GoalKind.child,
        id = s.id,
        title = s.title,
        parentId = s.longTermId,
        dreamId = dreamIdOfParent,
        priority = s.priority,
        dueAt = s.dueAt,
        archived = s.archived,
        color = null;

  final GoalKind kind;
  final int id;
  final String title;
  final int? parentId; // null for top-level goal
  final int? dreamId; // non-null for top-level; derived for child
  final int priority;
  final DateTime? dueAt;
  final bool archived;
  final int? color; // reserved for future styling
}

class GoalRepositoryUnified {
  GoalRepositoryUnified(this._db);
  final IsarService _db;
  Isar get _isar => _db.isar;

  // Top-level goals under a Dream (LongTerm)
  Stream<List<GoalNode>> watchByDream(int? dreamId, {bool includeArchived = false}) {
    final longRepo = LongTermRepository(_db);
    return longRepo.watchByDream(dreamId, includeArchived: includeArchived).map(
      (list) => list.map((l) => GoalNode.parent(l)).toList(),
    );
  }

  // Child goals under a Goal (ShortTerm under LongTerm)
  Stream<List<GoalNode>> watchChildren(int parentGoalId, {bool includeArchived = false}) {
    final shortRepo = ShortTermRepository(_db);
    return shortRepo
        .watchByLongTerm(parentGoalId, includeArchived: includeArchived)
        .asyncMap((shorts) async {
      // Need dreamId for children; fetch the parent LongTerm once
      final parent = await _isar.longTerms.get(parentGoalId);
      final parentDreamId = parent?.dreamId;
      return shorts.map((s) => GoalNode.child(s, dreamIdOfParent: parentDreamId)).toList();
    });
  }

  Future<void> addGoal({
    required String title,
    required int dreamId,
    int? parentGoalId,
    int priority = 1,
    DateTime? dueAt,
  }) async {
    if (parentGoalId == null) {
      await LongTermRepository(_db).put(
        LongTerm(title: title, dreamId: dreamId, priority: priority, dueAt: dueAt),
      );
    } else {
      await ShortTermRepository(_db).put(
        ShortTerm(title: title, longTermId: parentGoalId, priority: priority, dueAt: dueAt),
      );
    }
  }

  Future<void> deleteGoal(GoalNode goal) async {
    if (goal.kind == GoalKind.parent) {
      await LongTermRepository(_db).delete(goal.id);
    } else {
      await ShortTermRepository(_db).delete(goal.id);
    }
  }

  Future<void> setTags(GoalNode goal, List<Tag> tags) async {
    if (goal.kind == GoalKind.parent) {
      final repo = LongTermRepository(_db);
      final entity = await repo.getById(goal.id);
      if (entity != null) await repo.setTags(entity, tags);
    } else {
      final repo = ShortTermRepository(_db);
      final entity = await repo.getById(goal.id);
      if (entity != null) await repo.setTags(entity, tags);
    }
  }

  Future<List<Tag>> loadTags(GoalNode goal) async {
    if (goal.kind == GoalKind.parent) {
      final entity = await _isar.longTerms.get(goal.id);
      if (entity == null) return const [];
      await entity.tags.load();
      return entity.tags.toList();
    } else {
      final entity = await _isar.shortTerms.get(goal.id);
      if (entity == null) return const [];
      await entity.tags.load();
      return entity.tags.toList();
    }
  }
}

class GoalWithTags {
  GoalWithTags({required this.item, required this.tags});
  final LongTerm item;
  final List<Tag> tags;
}

class LongTermRepository {
  LongTermRepository(this._db);
  final IsarService _db;
  Isar get _isar => _db.isar;

  Stream<List<LongTerm>> watchByDream(int? dreamId,
      {bool includeArchived = false}) {
    final q = dreamId == null
        ? (includeArchived
            ? _isar.longTerms.where().sortByCreatedAt()
            : _isar.longTerms
                .filter()
                .archivedEqualTo(false)
                .sortByCreatedAt())
        : (includeArchived
            ? _isar.longTerms
                .filter()
                .dreamIdEqualTo(dreamId)
                .sortByCreatedAt()
            : _isar.longTerms
                .filter()
                .dreamIdEqualTo(dreamId)
                .and()
                .archivedEqualTo(false)
                .sortByCreatedAt());
    return q.watch(fireImmediately: true);
  }

  Future<void> put(LongTerm item) async {
    if (item.dreamId == null) {
      throw ArgumentError('Goal must be linked to a Dream');
    }
    item.updatedAt = DateTime.now();
    await _isar.writeTxn(() async => _isar.longTerms.put(item));
  }

  Future<LongTerm?> getById(int id) async {
    return _isar.longTerms.get(id);
  }

  Stream<GoalWithTags?> watchWithTags(int id) {
    return _isar.longTerms.watchObject(id, fireImmediately: true).asyncMap((item) async {
      if (item == null) return null;
      await item.tags.load();
      return GoalWithTags(item: item, tags: item.tags.toList());
    });
  }

  Future<void> setTags(LongTerm item, List<Tag> tags) async {
    await _isar.writeTxn(() async {
      item.updatedAt = DateTime.now();
      // Persist field changes
      await _isar.longTerms.put(item);
      // Use an attached instance for link operations
      final attached = await _isar.longTerms.get(item.id);
      if (attached == null) return;
      await attached.tags.load();
      await attached.tags.reset();
      attached.tags.addAll(tags);
      await attached.tags.save();
    });
  }

  Future<void> delete(Id id) async {
    await _isar.writeTxn(() async => _isar.longTerms.delete(id));
  }
}

class ShortTermRepository {
  ShortTermRepository(this._db);
  final IsarService _db;
  Isar get _isar => _db.isar;

  Stream<List<ShortTerm>> watchByLongTerm(int? longTermId,
      {bool includeArchived = false}) {
    final q = longTermId == null
        ? (includeArchived
            ? _isar.shortTerms.where().sortByCreatedAt()
            : _isar.shortTerms
                .filter()
                .archivedEqualTo(false)
                .sortByCreatedAt())
        : (includeArchived
            ? _isar.shortTerms
                .filter()
                .longTermIdEqualTo(longTermId)
                .sortByCreatedAt()
            : _isar.shortTerms
                .filter()
                .longTermIdEqualTo(longTermId)
                .and()
                .archivedEqualTo(false)
                .sortByCreatedAt());
    return q.watch(fireImmediately: true);
  }

  Future<void> put(ShortTerm item) async {
    item.updatedAt = DateTime.now();
    await _isar.writeTxn(() async => _isar.shortTerms.put(item));
  }

  Future<void> delete(Id id) async {
    await _isar.writeTxn(() async => _isar.shortTerms.delete(id));
  }

  Future<void> setTags(ShortTerm item, List<Tag> tags) async {
    await _isar.writeTxn(() async {
      item.updatedAt = DateTime.now();
      // Persist field changes
      await _isar.shortTerms.put(item);
      // Use an attached instance for link operations
      final attached = await _isar.shortTerms.get(item.id);
      if (attached == null) return;
      await attached.tags.load();
      await attached.tags.reset();
      attached.tags.addAll(tags);
      await attached.tags.save();
    });
  }

  Future<ShortTerm?> getById(int id) async {
    return _isar.shortTerms.get(id);
  }
}
