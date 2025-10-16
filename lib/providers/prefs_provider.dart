import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../services/prefs_service.dart';

final prefsServiceProvider = Provider<PrefsService>((ref) {
  return PrefsService();
});

