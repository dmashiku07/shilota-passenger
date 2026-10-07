import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'session_storage.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

final sessionStorageProvider = Provider<SessionStorage>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SessionStorage(prefs);
});
