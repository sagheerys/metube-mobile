import 'dart:io';

/// نسخة محفوظة على القرص — اسمها يحمل تاريخها فلا حاجة لقراءة الملف.
class BackupFile {
  const BackupFile({
    required this.path,
    required this.name,
    required this.at,
    required this.sizeBytes,
  });

  final String path;
  final String name;
  final DateTime at;
  final int sizeBytes;
}

/// **مخزن النسخ الدوّار** (طلب المالك 2026-09-04: «نسخ كثيرة تصل إلى ٧
/// تلقائياً ويحذف القديم»).
///
/// ثلاثة قرارات، لكلٍّ سبب من عطل وقع فعلاً:
///
/// 1. **اسم مؤرَّخ لكل نسخة — لا ملف واحد يُدهس.** الملف الثابت كان
///    يعني أن نسخة فاسدة تمحو الصالحة قبلها بلا رجعة. وقد ضربنا هذا
///    من جهة أخرى أيضاً: أندرويد 11+ يسجّل **مالكاً** لكل ملف في
///    `Download/`، فالتطبيق المُعاد تثبيته لا يستطيع الكتابة فوق ملف
///    أنشأته نسخة سابقة — `errno 13` الذي رآه المالك بلقطة. الاسم
///    الجديد في كل مرة يجعل التعارض مستحيلاً بنيوياً.
///
/// 2. **كتابة ذرّية**: `.tmp` ثم إعادة تسمية. انقطاعٌ في منتصف الكتابة
///    (قتل التطبيق، بطارية) لا يترك نصف ملف يبدو صالحاً.
///
/// 3. **لا تُكتب نسخة مطابقة لأحدث نسخة.** بلا هذا تصير السبع «سبع
///    لحظات متتالية» لا سبعة تغييرات — فتُطرد نسخة الأمس بنسخ اليوم
///    المتطابقة.
class BackupRotation {
  BackupRotation({
    required this.directory,
    required this.prefix,
    this.keep = defaultKeep,
  }) : assert(keep > 0, 'الاحتفاظ بصفر نسخة يعني حذف كل شيء');

  /// العدد المعتمد (طلب المالك) — الملف كيلوبايتات، والعدد الثابت
  /// أوضح للمستخدم من تدرّج زمني.
  static const int defaultKeep = 7;

  static const String extension = '.json';
  static const String _tempExtension = '.tmp';

  /// مجلد النسخ — `<وسائط التطبيق>/backups`.
  final String directory;

  /// بادئة الاسم: `metube_lite` أو `metube_super`.
  final String prefix;

  final int keep;

  /// `prefix_2026-09-04_094233.json` — يُرتَّب أبجدياً فيُرتَّب زمنياً.
  String fileNameFor(DateTime at) => '${prefix}_${stampOf(at)}$extension';

  static String stampOf(DateTime at) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${at.year}-${two(at.month)}-${two(at.day)}'
        '_${two(at.hour)}${two(at.minute)}${two(at.second)}';
  }

  /// التاريخ من الاسم — `null` لاسم لا يتبع النمط.
  DateTime? dateOf(String fileName) {
    if (!fileName.startsWith('${prefix}_') ||
        !fileName.endsWith(extension)) {
      return null;
    }
    final stamp = fileName.substring(
        prefix.length + 1, fileName.length - extension.length);
    if (stamp.length != 17 || stamp[10] != '_') return null;
    return DateTime.tryParse('${stamp.substring(0, 10)} '
        '${stamp.substring(11, 13)}:${stamp.substring(13, 15)}:'
        '${stamp.substring(15, 17)}');
  }

  /// النسخ المحفوظة — **الأحدث أولاً**. مجلد غير موجود ⇒ قائمة فارغة.
  Future<List<BackupFile>> list() async {
    final dir = Directory(directory);
    if (!await dir.exists()) return const [];
    final out = <BackupFile>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.path.split(RegExp(r'[/\\]')).last;
      final at = dateOf(name);
      if (at == null) continue; // ملفات قديمة أو غريبة لا تُلمس
      out.add(BackupFile(
        path: entity.path,
        name: name,
        at: at,
        sizeBytes: await entity.length(),
      ));
    }
    out.sort((a, b) => b.at.compareTo(a.at));
    return out;
  }

  Future<BackupFile?> latest() async => (await list()).firstOrNull;

  /// يكتب نسخة جديدة ويحذف ما زاد عن [keep].
  ///
  /// يعيد `null` إن كان المحتوى **مطابقاً لأحدث نسخة** — لا شيء تغيّر
  /// فلا داعي لإهدار خانة من السبع.
  Future<BackupFile?> write(String contents, {DateTime? at}) async {
    final dir = Directory(directory);
    await dir.create(recursive: true);

    final newest = await latest();
    if (newest != null) {
      final previous = await File(newest.path).readAsString();
      if (previous == contents) return null;
    }

    final stamp = at ?? DateTime.now();
    final name = fileNameFor(stamp);
    final target = '$directory/$name';
    final temp = File('$target$_tempExtension');
    await temp.writeAsString(contents, flush: true);
    // النقلة الذرّية: من هنا فقط يراها القارئ.
    final file = await temp.rename(target);

    await prune();
    return BackupFile(
      path: file.path,
      name: name,
      at: stamp,
      sizeBytes: await file.length(),
    );
  }

  /// يحذف الأقدم حتى يبقى [keep] — ويعيد عدد المحذوف.
  Future<int> prune() async {
    final all = await list();
    if (all.length <= keep) return 0;
    var deleted = 0;
    for (final file in all.skip(keep)) {
      try {
        await File(file.path).delete();
        deleted++;
      } on FileSystemException {
        // ملف يملكه تثبيت سابق (أندرويد 11+) — يُترك ولا يُسقط الدورة.
      }
    }
    return deleted;
  }

  Future<String> read(BackupFile file) => File(file.path).readAsString();
}
