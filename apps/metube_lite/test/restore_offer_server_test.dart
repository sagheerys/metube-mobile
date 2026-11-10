import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/di.dart';
import 'package:metube_lite/features/downloads_library/library_providers.dart';
import 'package:metube_lite/features/downloads_library/local_item.dart';
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

  Widget host(
    BackupRotation rotation, {
    List<LocalItem> downloads = const [],
    MemoryKeyValueStore? store,
  }) => ProviderScope(
    overrides: [
      keyValueStoreProvider.overrideWithValue(store ?? MemoryKeyValueStore()),
      secretStoreProvider.overrideWithValue(MemorySecretStore()),
      prefsMutexProvider.overrideWithValue(PrefsMutex()),
      initialSettingsProvider.overrideWithValue(const LiteSettings()),
      loggerProvider.overrideWithValue(
        MTLogger(filePath: '${folder.path}/log.txt'),
      ),
      backupRotationProvider.overrideWithValue(rotation),
      localMediaProvider.overrideWith((ref) async => downloads),
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

  testWidgets('**the guard**: after a reinstall the app cannot see its own '
      'backups, so it offers the picker instead', (tester) async {
    // Measured on the owner's phone 2026-11-10 (Android 16): every copy in
    // the backups folder had lost its owner, the old offer found nothing,
    // and a reinstall without Google's backup kept no settings.
    final rotation = BackupRotation(
      directory: folder.path,
      prefix: liteBackupPrefix,
    );
    final store = MemoryKeyValueStore();
    await tester.pumpWidget(
      host(
        rotation,
        store: store,
        downloads: [
          LocalItem(
            key: 'k',
            path: '/storage/emulated/0/Download/MeTube_Lite/clip.mp4',
            title: 'clip',
            sizeBytes: 1,
            modified: DateTime(2026, 11, 1),
          ),
        ],
      ),
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('START'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.text('Bring back your settings?'), findsOneWidget);
    expect(find.text('Choose a backup'), findsOneWidget);
    expect(await store.getBool('auto_restore_offered'), isTrue);
  });

  testWidgets('a first install, with no downloads, is asked nothing', (
    tester,
  ) async {
    final rotation = BackupRotation(
      directory: folder.path,
      prefix: liteBackupPrefix,
    );
    final store = MemoryKeyValueStore();
    await tester.pumpWidget(host(rotation, store: store));
    await tester.runAsync(() async {
      await tester.tap(find.text('START'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.text('Bring back your settings?'), findsNothing);
    // Asked again later: the downloads may only be hidden for want of the
    // media permission.
    expect(await store.getBool('auto_restore_offered'), isNot(isTrue));
  });
}
