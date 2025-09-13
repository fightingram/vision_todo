import 'package:isar/isar.dart';

import '../models/task.dart';
import '../services/isar_service.dart';

class TaskRepository {
  TaskRepository(this._db);
  final IsarService _db;

  Isar get _isar => _db.isar;

  Future<Task> addQuick(String title) async {
    final task = Task(title: title);
    await _isar.writeTxn(() async {
      await _isar.tasks.put(task);
    });
    return task;
  }

  Future<Task> add(Task task) async {
    await _isar.writeTxn(() async {
      await _isar.tasks.put(task);
    });
    return task;
  }

  Future<void> update(Task task) async {
    task.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.tasks.put(task);
    });
  }

  Future<void> delete(Id id) async {
    await _isar.writeTxn(() async {
      await _isar.tasks.delete(id);
    });
  }

  Future<void> toggleDone(Task task) async {
    final now = DateTime.now();
    if (task.status == TaskStatus.todo) {
      task.status = TaskStatus.done;
      task.doneAt = now;
    } else {
      task.status = TaskStatus.todo;
      task.doneAt = null;
    }
    task.updatedAt = now;
    await _isar.writeTxn(() async {
      await _isar.tasks.put(task);
    });
  }

  Future<void> setStatus(Task task, TaskStatus status) async {
    final now = DateTime.now();
    task.status = status;
    task.doneAt = status == TaskStatus.done ? now : null;
    task.updatedAt = now;
    await _isar.writeTxn(() async {
      await _isar.tasks.put(task);
    });
  }

  Future<void> setTriageDecision(Task task, DateTime weekStart,
      {required bool planned}) async {
    task.triagedWeekStart = weekStart;
    task.plannedWeekStart = planned ? weekStart : null;
    task.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.tasks.put(task);
    });
  }

  Stream<List<Task>> watchAll({bool includeDone = false}) {
    // Watch all, then filter in memory to include both todo/doing when exclude done
    final base = _isar.tasks.where().sortByCreatedAt().watch(fireImmediately: true).asBroadcastStream();
    if (includeDone) return base;
    return base.map((list) => list.where((t) => t.status != TaskStatus.done).toList());
  }

  // Watch tasks linked to a specific Term
  Stream<List<Task>> watchByTerm(int termId) {
    return _isar.tasks
        .filter()
        .shortTermIdEqualTo(termId)
        .sortByCreatedAt()
        .watch(fireImmediately: true)
        .asBroadcastStream();
  }

  Stream<List<Task>> watchUnlinked() {
    return _isar.tasks
        .filter()
        .shortTermIdIsNull()
        .sortByCreatedAt()
        .watch(fireImmediately: true)
        .asBroadcastStream();
  }

  // Watch a single task by its id
  Stream<Task?> watchById(Id id) {
    return _isar.tasks.watchObject(id, fireImmediately: true).asBroadcastStream();
  }
}
