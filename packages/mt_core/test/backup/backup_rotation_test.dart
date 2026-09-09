import 'dart:io';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// **Guards for the rotating store** (requested 2026-09-04: "seven copies
/// automatically, deleting the oldest"), and each one documents a defect
/// rather than a preference.
void main() {
  late Directory temp;
  late BackupRotation rotation;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('mtf_rotation_');
    // **Spacing is disabled here on purpose**: these guards test the limit,
    // the atomicity and the prefix, and their timestamps are minutes apart.
    // Spacing has its own guards below.
    rotation = BackupRotation(
      directory: temp.path,
      prefix: 'metube_lite',
      minSpacing: Duration.zero,
    );
  });
  tearDown(() => temp.delete(recursive: true));

  DateTime at(int minute) => DateTime(2026, 9, 4, 10, minute);

  test('العدد المعتمد سبع نسخ', () {
    expect(BackupRotation.defaultKeep, 7);
    expect(rotation.keep, 7);
  });

  test('الاسم مؤرَّخ ويُقرأ تاريخه منه', () {
    final name = rotation.fileNameFor(DateTime(2026, 9, 4, 9, 42, 33));
    expect(name, 'metube_lite_2026-09-04_094233.json');
    expect(rotation.dateOf(name), DateTime(2026, 9, 4, 9, 42, 33));
  });

  test('اسم لا يتبع النمط لا يُقرأ ولا يُلمس', () async {
    // **A file from an earlier install**: Android 11+ forbids writing over
    // it or deleting it (`errno 13`, seen in a screenshot). Ignoring it is
    // what makes the conflict impossible.
    await File('${temp.path}/metube_lite_backup.json').writeAsString('{}');
    await File('${temp.path}/ملف عشوائي.txt').writeAsString('x');
    expect(rotation.dateOf('metube_lite_backup.json'), isNull);

    await rotation.write('{"a":1}');
    final all = await rotation.list();
    expect(all, hasLength(1), reason: 'الجديد وحده يُحسب نسخة');
    expect(
      await File('${temp.path}/metube_lite_backup.json').exists(),
      isTrue,
      reason: 'ولا يُحذف ملف التثبيت السابق',
    );
  });

  test('يحتفظ بسبع ويحذف الأقدم، والأحدث أولاً', () async {
    for (var i = 0; i < 10; i++) {
      await rotation.write('{"n":$i}', at: at(i));
    }
    final all = await rotation.list();
    expect(all, hasLength(7));
    expect(all.first.at, at(9), reason: 'الأحدث أولاً');
    expect(all.last.at, at(3), reason: 'الثلاث الأقدم حُذفت');
    expect(await rotation.read(all.first), '{"n":9}');
  });

  test('محتوى مطابق لأحدث نسخة لا يُكتب ولا يطرد نسخة', () async {
    await rotation.write('{"a":1}', at: at(1));
    await rotation.write('{"a":2}', at: at(2));

    // Without this guard the seven become seven moments rather than seven
    // changes.
    expect(await rotation.write('{"a":2}', at: at(3)), isNull);
    expect(await rotation.list(), hasLength(2));

    expect(await rotation.write('{"a":3}', at: at(4)), isNotNull);
    expect(await rotation.list(), hasLength(3));
  });

  test('الكتابة ذرّية: لا يبقى ملف مؤقت ولا نصف نسخة', () async {
    await rotation.write('{"a":1}');
    final names = [
      for (final entity in temp.listSync())
        entity.path.split(RegExp(r'[/\\]')).last,
    ];
    expect(names, hasLength(1));
    expect(names.single, endsWith('.json'));
    expect(names.single, isNot(contains('.tmp')));
  });

  test('مجلد غير موجود ⇒ قائمة فارغة لا رمي', () async {
    final missing = BackupRotation(
      directory: '${temp.path}/none',
      prefix: 'metube_lite',
    );
    expect(await missing.list(), isEmpty);
    expect(await missing.latest(), isNull);
  });

  test('البادئة تفصل التطبيقين في مجلد واحد', () async {
    await rotation.write('{"lite":1}', at: at(1));
    final superRotation = BackupRotation(
      directory: temp.path,
      prefix: 'metube_super',
      minSpacing: Duration.zero,
    );
    await superRotation.write('{"super":1}', at: at(1));

    expect(await rotation.list(), hasLength(1));
    expect(await superRotation.list(), hasLength(1));
    expect(await rotation.read((await rotation.list()).single), '{"lite":1}');
  });

  test('keep مخصص يُحترم', () async {
    final three = BackupRotation(
      directory: temp.path,
      prefix: 'metube_lite',
      keep: 3,
      minSpacing: Duration.zero,
    );
    for (var i = 0; i < 6; i++) {
      await three.write('{"n":$i}', at: at(i));
    }
    expect(await three.list(), hasLength(3));
  });

  group('التباعد الزمني — عطل مقيس على جهاز المالك 2026-09-05', () {
    late BackupRotation spaced;

    setUp(() {
      spaced = BackupRotation(directory: temp.path, prefix: 'metube_lite');
    });

    test('الافتراضي ساعة', () {
      expect(BackupRotation.defaultSpacing, const Duration(hours: 1));
      expect(spaced.minSpacing, const Duration(hours: 1));
    });

    test('دفعة تحميل كاملة تبقى خانة واحدة تحمل آخر حالة', () async {
      // The real case: seven changes in six minutes consumed all seven
      // slots, so the entire backup history covered six minutes.
      for (var i = 0; i < 7; i++) {
        await spaced.write('{"n":$i}', at: at(i));
      }
      final all = await spaced.list();
      expect(all, hasLength(1), reason: 'الدفعة خانة واحدة لا سبع');
      expect(
        await spaced.read(all.single),
        '{"n":6}',
        reason: 'وأحدث حالة هي المحفوظة — لا الأولى',
      );
    });

    test('بعد انقضاء الفاصل تُفتح خانة جديدة', () async {
      await spaced.write('{"a":1}', at: DateTime(2026, 9, 5, 10));
      await spaced.write('{"a":2}', at: DateTime(2026, 9, 5, 10, 30));
      expect(await spaced.list(), hasLength(1));

      // A fixed grid: a new calendar hour means a new slot, even if sixty
      // minutes have not passed since the last write (10:30 then 11:01).
      await spaced.write('{"a":3}', at: DateTime(2026, 9, 5, 11, 1));
      expect(await spaced.list(), hasLength(2));

      // Continuous activity every half hour stays a history rather than one
      // creeping slot.
      await spaced.write('{"a":5}', at: DateTime(2026, 9, 5, 11, 40));
      await spaced.write('{"a":6}', at: DateTime(2026, 9, 5, 12, 10));
      expect(await spaced.list(), hasLength(3));

      await spaced.write('{"a":4}', at: DateTime(2026, 9, 6, 9));
      final all = await spaced.list();
      expect(all, hasLength(4));
      expect(all.first.at.day, 6, reason: 'الأحدث أولاً');
    });

    test('سبع خانات متباعدة تغطي سبع ساعات لا ست دقائق', () async {
      for (var hour = 0; hour < 10; hour++) {
        await spaced.write('{"h":$hour}', at: DateTime(2026, 9, 5, hour));
      }
      final all = await spaced.list();
      expect(all, hasLength(7));
      expect(
        all.first.at.difference(all.last.at),
        const Duration(hours: 6),
        reason: 'المدى الحقيقي للذاكرة الاحتياطية',
      );
    });

    test('الاستبدال لا يترك المستخدم بلا نسخة لحظةً واحدة', () async {
      await spaced.write('{"a":1}', at: at(1));
      // The old copy is deleted **after** the replacement is written
      // successfully: the number of visible files never drops below one.
      final result = await spaced.write('{"a":2}', at: at(2));
      expect(result, isNotNull);
      final files = temp.listSync().map((e) => e.path).toList();
      expect(files, hasLength(1));
      expect(await spaced.read((await spaced.list()).single), '{"a":2}');
    });
  });
}
