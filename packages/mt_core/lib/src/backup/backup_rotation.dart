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
///
/// 4. **تباعد زمني بين الخانات** ([minSpacing]) — أُضيف بعد فحص جهاز
///    المالك (2026-09-05): النسخ السبع في Super كانت كلها بين 00:39
///    و00:45، **ست دقائق تغطيها كل الذاكرة الاحتياطية**. الحدّ «٧»
///    كان يعمل تماماً، لكن كل تغيير في قائمة أو وسم يطلب نسخة، وتحميل
///    دفعة من يوتيوب تغييرٌ لكل مقطع — فتلتهم الدفعة الواحدة الخانات
///    السبع وتطرد كل ما قبلها. الفرق الثالث لا يكفي هنا: كل نسخة
///    **مختلفة** فعلاً عن سابقتها.
///
///    فالنسخة الأحدث من [minSpacing] **تحلّ محلّ** التي قبلها في نفس
///    الخانة بدل أن تفتح خانة جديدة: أحدث حالة محفوظة دائماً، والسبع
///    تمتد ساعات أو أياماً بحسب استعمالك.
class BackupRotation {
  BackupRotation({
    required this.directory,
    required this.prefix,
    this.keep = defaultKeep,
    this.minSpacing = defaultSpacing,
  }) : assert(keep > 0, 'الاحتفاظ بصفر نسخة يعني حذف كل شيء');

  /// العدد المعتمد (طلب المالك) — الملف كيلوبايتات، والعدد الثابت
  /// أوضح للمستخدم من تدرّج زمني.
  static const int defaultKeep = 7;

  /// ساعة: تحميل دفعة كاملة يبقى خانةً واحدة، ويوم استعمال عادي يترك
  /// عدة خانات — والسبع تصير تاريخاً لا لقطةً مكرَّرة.
  static const Duration defaultSpacing = Duration(hours: 1);

  static const String extension = '.json';
  static const String _tempExtension = '.tmp';

  /// مجلد النسخ — `<وسائط التطبيق>/backups`.
  final String directory;

  /// بادئة الاسم: `metube_lite` أو `metube_super`.
  final String prefix;

  final int keep;

  /// أقل فاصل زمني بين خانتين. `Duration.zero` يعطّل التباعد.
  final Duration minSpacing;

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

    final stamp = at ?? DateTime.now();
    final newest = await latest();
    if (newest != null) {
      final previous = await File(newest.path).readAsString();
      if (previous == contents) return null;
    }

    // **الاستبدال لا الإضافة** داخل نفس الخانة الزمنية: تُحذف القديمة
    // بعد نجاح كتابة البديل لا قبله، فانقطاعٌ في المنتصف يترك القديمة
    // سليمة بدل أن يترك المستخدم بلا نسخة أصلاً.
    //
    // الخانة تُحسب على **شبكة ثابتة** لا بفارق عن آخر كتابة: «أحدث من
    // ساعة» كان يجعل نشاطاً كل نصف ساعة يزحف بالخانة الوحيدة إلى
    // الأبد فلا يُفتح تاريخ أصلاً.
    final replace = newest != null &&
        minSpacing > Duration.zero &&
        _slotOf(stamp) == _slotOf(newest.at);
    final name = fileNameFor(stamp);
    final target = '$directory/$name';
    final temp = File('$target$_tempExtension');
    await temp.writeAsString(contents, flush: true);
    // النقلة الذرّية: من هنا فقط يراها القارئ.
    final file = await temp.rename(target);

    if (replace && newest.path != file.path) {
      try {
        await File(newest.path).delete();
      } on FileSystemException {
        // ملف يملكه تثبيت سابق — يُترك، وprune يتكفّل بالحدّ.
      }
    }
    await prune();
    return BackupFile(
      path: file.path,
      name: name,
      at: stamp,
      sizeBytes: await file.length(),
    );
  }

  /// رقم الخانة على شبكة [minSpacing] الثابتة — ساعةُ التقويم عملياً.
  int _slotOf(DateTime at) =>
      at.millisecondsSinceEpoch ~/ minSpacing.inMilliseconds;

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
