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

  Stream<List<Task>> watchAll({bool includeDone = false}) {
    final q = includeDone
        ? _isar.tasks.where().sortByCreatedAt()
        : _isar.tasks.filter().statusEqualTo(TaskStatus.todo).sortByCreatedAt();
    return q.watch(fireImmediately: true).asBroadcastStream();
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
}
