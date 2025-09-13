import 'package:hooks_riverpod/hooks_riverpod.dart';

enum WeekStart { monday, sunday }

class AppSettings {
  const AppSettings({
    this.weekStart = WeekStart.monday,
    this.animations = true,
    this.showCompleted = false,
  });
  final WeekStart weekStart;
  final bool animations;
  final bool showCompleted;

  AppSettings copyWith({WeekStart? weekStart, bool? animations, bool? showCompleted}) =>
      AppSettings(
        weekStart: weekStart ?? this.weekStart,
        animations: animations ?? this.animations,
        showCompleted: showCompleted ?? this.showCompleted,
      );
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings());

  void toggleAnimations() => state = state.copyWith(animations: !state.animations);
  void toggleShowCompleted() =>
      state = state.copyWith(showCompleted: !state.showCompleted);
  void setWeekStart(WeekStart start) => state = state.copyWith(weekStart: start);
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
