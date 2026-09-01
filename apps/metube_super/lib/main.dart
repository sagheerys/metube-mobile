import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'di.dart';
import 'features/settings/settings_state.dart';
import 'features/shared/stores.dart';

/// bootstrap فقط: تهيئة التخزين وتحميل لقطة الإعدادات ثم runApp.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initMTL10n();

  final prefs = await SharedPreferences.getInstance();
  final store = SharedPrefsKeyValueStore(prefs);
  const secrets = SecureSecretStore();
  final initialSettings = await SuperSettings.load(store, secrets);

  runApp(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        secretStoreProvider.overrideWithValue(secrets),
        initialSettingsProvider.overrideWithValue(initialSettings),
      ],
      child: const SuperApp(),
    ),
  );
}
