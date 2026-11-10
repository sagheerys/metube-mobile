import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/di.dart';
import 'package:metube_lite/features/settings/auto_backup.dart';
import 'package:metube_lite/features/settings/restore_prompt.dart';
import 'package:metube_lite/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// The restore offered on a fresh install names the server the copy points
/// at (security review 2026-11-05): the newest file in a public folder is
/// not always one this app wrote.
void main() {
  late Directory folder;

  setUp(() => folder = Directory.systemTemp.createTempSync('lite_offer_'));
  tearDown(() => folder.deleteSync(recursive: true));

  Widget host(BackupRotation rotation) => ProviderScope(
    overrides: [
      keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
      secretStoreProvider.overrideWithValue(MemorySecretStore()),
      prefsMutexProvider.overrideWithValue(PrefsMutex()),
      initialSettingsProvider.overrideWithValue(const LiteSettings()),
      loggerProvider.overrideWithValue(
        MTLogger(filePath: '${folder.path}/log.txt'),
      ),
      backupRotationProvider.overrideWithValue(rotation),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      theme: mtTheme(MTVariant.lite, Brightness.light),
      localizationsDelegates: MTLocalizations.localizationsDelegates,
      supportedLocales: MTLocalizations.supportedLocales,
      home: Scaffold(
        body: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => maybeOfferAutoRestore(context, ref),
            child: const Text('START'),
          ),
        ),
      ),
    ),
  );

  testWidgets('**the guard**: the offer says which server the copy names', (
    tester,
  ) async {
    final rotation = BackupRotation(
      directory: folder.path,
      prefix: liteBackupPrefix,
    );
    File('${folder.path}/${rotation.fileNameFor(DateTime(2026, 11, 10, 9))}')
        .writeAsStringSync(
          jsonEncode({
            'app': 'MTF',
            'variant': 'lite',
            'version': 3,
            'prefs': {
              'server_url': {'t': 's', 'v': 'https://metube.example.com'},
            },
          }),
        );
    await tester.pumpWidget(host(rotation));
    await tester.runAsync(() async {
      await tester.tap(find.text('START'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('Server in this backup:'), findsOneWidget);
    expect(find.textContaining('metube.example.com'), findsOneWidget);
  });
}
