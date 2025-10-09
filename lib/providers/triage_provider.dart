import 'package:hooks_riverpod/hooks_riverpod.dart';

// If set to a DateTime (week start), auto-opening triage is skipped for that week.
final triageSkipWeekProvider = StateProvider<DateTime?>((ref) => null);

// When true, triage ignores this week's completion state and re-triages all
// non-done tasks. It should be set before opening the triage page and reset
// on exit.
final triageForceProvider = StateProvider<bool>((ref) => false);

// Holds task IDs triaged in the current forced session so they won't reappear
// while triageForceProvider is true.
final triageSessionExcludedIdsProvider =
    StateProvider<Set<int>>((ref) => <int>{});
