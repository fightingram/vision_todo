import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/task.dart';

enum WeekStart { monday, sunday }

class AppSettings {
  const AppSettings({
    this.weekStart = WeekStart.monday,
    this.animations = true,
    this.showCompleted = false,
    this.statusFilter = const {},
    this.priorityFilter = const {},
  });
  final WeekStart weekStart;
  final bool animations;
  final bool showCompleted;
  final Set<TaskStatus> statusFilter; // empty = no status filter
  final Set<int> priorityFilter; // empty = no priority filter (0..3)

  AppSettings copyWith({WeekStart? weekStart, bool? animations, bool? showCompleted, Set<TaskStatus>? statusFilter, Set<int>? priorityFilter}) =>
      AppSettings(
        weekStart: weekStart ?? this.weekStart,
        animations: animations ?? this.animations,
        showCompleted: showCompleted ?? this.showCompleted,
        statusFilter: statusFilter ?? this.statusFilter,
        priorityFilter: priorityFilter ?? this.priorityFilter,
      );
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings());

  void toggleAnimations() => state = state.copyWith(animations: !state.animations);
  void toggleShowCompleted() =>
      state = state.copyWith(showCompleted: !state.showCompleted);
  void setWeekStart(WeekStart start) => state = state.copyWith(weekStart: start);
  void setStatusFilter(Set<TaskStatus> statuses) =>
      state = state.copyWith(statusFilter: statuses);
  void setPriorityFilter(Set<int> priorities) =>
      state = state.copyWith(priorityFilter: priorities);
  void clearTaskFilters() =>
      state = state.copyWith(statusFilter: {}, priorityFilter: {});
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
