// بوابة 6: التحقق من هجرة نسخة Super القديمة الحقيقية (`MTSBACKUP1`).
// يستورد الملف بمفتاحه إلى مخزن ذاكرة ويطبع **إحصاءً فقط** — لا يطبع
// أي رابط ولا اسم ملف ولا اعتماد (نفس قاعدة تعقيم السجلات م-32).
//
// dart tool/verify_legacy_backup.dart <backup.json> <key.txt>
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:mt_core/mt_core.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    print('الاستعمال: dart tool/verify_legacy_backup.dart <backup> <key>');
    exit(64);
  }
  final backup = File(args[0]);
  final keyFile = File(args[1]);
  if (!backup.existsSync() || !keyFile.existsSync()) {
    print('ملف مفقود');
    exit(66);
  }

  final store = MemoryKeyValueStore();
  final secrets = MemorySecretStore();
  final service = BackupService(
    store: store,
    secrets: secrets,
    mutex: PrefsMutex(),
    variant: 'super',
  );

  final contents = backup.readAsStringSync();
  print('الترويسة: ${BackupCrypto.headerOf(contents)}');

  // المفتاح أولاً — نسخة من جهاز آخر لا تُفك بمفتاح هذا الجهاز.
  // (`importKeyFile` أُزيل من الخدمة مع مفهوم المفتاح — 2026-09-04 —
  // وهذه أداة تحقق يدوية تبذر المفتاح مباشرة في مخزن أسرار الذاكرة.)
  final keyBase64 = BackupCrypto.decodeKeyFile(keyFile.readAsStringSync());
  if (keyBase64 == null) {
    print('ملف مفتاح غير صالح');
    exit(65);
  }
  await secrets.write(SecretKeys.backupAesKey, keyBase64);

  final ImportResult result;
  try {
    result = await service.importFromString(contents);
  } on Object catch (e) {
    print('فشل الاستيراد: ${e.runtimeType}');
    exit(70);
  }

  print('الصيغة: ${result.format.name} · مفاتيح مستعادة: '
      '${result.keysRestored}');
  print('اسم مستخدم مستعاد: '
      '${await secrets.read(SecretKeys.username) != null}');

  // ماذا وصل فعلاً؟ عدّ فقط.
  final mutex = PrefsMutex();
  final playlists =
      await PlaylistsStore(store: store, mutex: mutex).readAll();
  final tags = TagsIndex(store: store, mutex: mutex);
  final offline = await OfflineIndex(store: store, mutex: mutex).readAll();
  final artwork = await ArtworkIndex(store: store, mutex: mutex).readAll();
  final tagCounts = await tags.allTagsWithCounts();

  print('قوائم محفوظة: ${playlists.length} '
      '(عناصرها: ${playlists.fold<int>(0, (n, p) => n + p.items.length)})');
  print('مداخل بصيغة المسارات القديمة: ${playlists.fold<int>(0, (n, p) => n + p.items.where((e) => e.isLegacy).length)}');
  print('وسوم: ${tagCounts.length} · عناصر موسومة: '
      '${(await tags.readAll()).length}');
  print('فهرس دون اتصال: ${offline.length} · فهرس الأغلفة: '
      '${artwork.length}');

  final keys = (await store.keys()).toList()..sort();
  print('كل المفاتيح المستعادة (${keys.length}): ${keys.join(', ')}');

  // مفاتيح الإعدادات المهمة — القيم الحساسة تُخفى.
  for (final key in const [
    'server_url',
    'active_url',
    'local_url',
    'video_quality',
    'theme_mode',
    'app_locale',
  ]) {
    final value = await store.get(key);
    final shown = value == null
        ? '—'
        : (key.contains('url') ? '[URL:${value.toString().length}]' : value);
    print('  $key = $shown');
  }

  final externals = await store.getStringList('external_urls');
  if (externals != null) print('  external_urls = ${externals.length} روابط');

  final positions =
      keys.where((k) => k.startsWith('playback_pos_')).length;
  print('مواضع استئناف: $positions');

  // فحص سلامة JSON للقوائم بعد الاستعادة.
  final raw = await store.getString(PlaylistsStore.prefsKey);
  if (raw != null) {
    final decoded = json.decode(raw);
    print('saved_playlists نوعه: ${decoded.runtimeType}');
  }
  exit(0);
}
