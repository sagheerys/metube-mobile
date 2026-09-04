import 'dart:io';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// **حرّاس المخزن الدوّار** (طلب المالك 2026-09-04: «٧ نسخ تلقائياً
/// ويحذف القديم»)، وكل واحد منها يوثّق عطلاً لا تفضيلاً.
void main() {
  late Directory temp;
  late BackupRotation rotation;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('mtf_rotation_');
    rotation = BackupRotation(directory: temp.path, prefix: 'metube_lite');
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
    // **ملف التثبيت السابق**: أندرويد 11+ يمنع الكتابة فوقه أو حذفه
    // (`errno 13` بلقطة المالك). تجاهله هو ما يجعل التعارض مستحيلاً.
    await File('${temp.path}/metube_lite_backup.json').writeAsString('{}');
    await File('${temp.path}/ملف عشوائي.txt').writeAsString('x');
    expect(rotation.dateOf('metube_lite_backup.json'), isNull);

    await rotation.write('{"a":1}');
    final all = await rotation.list();
    expect(all, hasLength(1), reason: 'الجديد وحده يُحسب نسخة');
    expect(await File('${temp.path}/metube_lite_backup.json').exists(), isTrue,
        reason: 'ولا يُحذف ملف التثبيت السابق');
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

    // بلا هذا الحارس تصير السبع «سبع لحظات» لا سبعة تغييرات.
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
        directory: '${temp.path}/none', prefix: 'metube_lite');
    expect(await missing.list(), isEmpty);
    expect(await missing.latest(), isNull);
  });

  test('البادئة تفصل التطبيقين في مجلد واحد', () async {
    await rotation.write('{"lite":1}', at: at(1));
    final superRotation =
        BackupRotation(directory: temp.path, prefix: 'metube_super');
    await superRotation.write('{"super":1}', at: at(1));

    expect(await rotation.list(), hasLength(1));
    expect(await superRotation.list(), hasLength(1));
    expect(await rotation.read((await rotation.list()).single), '{"lite":1}');
  });

  test('keep مخصص يُحترم', () async {
    final three =
        BackupRotation(directory: temp.path, prefix: 'metube_lite', keep: 3);
    for (var i = 0; i < 6; i++) {
      await three.write('{"n":$i}', at: at(i));
    }
    expect(await three.list(), hasLength(3));
  });
}
