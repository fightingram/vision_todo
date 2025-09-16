import 'package:hooks_riverpod/hooks_riverpod.dart';

// If set to a DateTime (week start), auto-opening triage is skipped for that week.
final triageSkipWeekProvider = StateProvider<DateTime?>((ref) => null);

