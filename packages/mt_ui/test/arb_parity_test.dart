import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **حارس تكافؤ اللغتين (قاعدة CLAUDE.md §حماية التطبيقين/1).**
///
/// كل نص واجهة يُكتب في `app_en.arb` و`app_ar.arb` **معاً في نفس
/// الدفعة**. القاعدة كانت نصاً في CLAUDE.md يمكن أن يُنسى — وهذا يجعلها
/// اختباراً **يسقط** إن نُسي مفتاح في أحد الملفين، أو اختلفت معاملاته،
/// أو تُرك بلا ترجمة.
///
/// لا يُعطَّل ولا يُتجاوَز: مفتاح أعرج يعني نصاً إنجليزياً يظهر لضيف
/// العائلة في واجهة عربية — أو انهيار `undefined_getter` عند البناء.
void main() {
  final dir = Directory('lib/src/l10n');

  Map<String, dynamic> load(String name) {
    final file = File('${dir.path}/$name');
    expect(file.existsSync(), isTrue, reason: 'ملف الترجمة مفقود: $name');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  /// مفاتيح النصوص وحدها — بلا `@@locale` ولا كتل الوصف `@key`.
  Set<String> messageKeys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  /// أسماء المعاملات داخل النص: `{percent}` و`{count}`.
  /// صيغ الجمع تُلتقط من فروعها (`few{{count} عناصر}`) فتتطابق.
  Set<String> placeholdersOf(String value) => RegExp(r'\{(\w+)\}')
      .allMatches(value)
      .map((m) => m.group(1)!)
      .toSet();

  late Map<String, dynamic> en;
  late Map<String, dynamic> ar;

  setUpAll(() {
    en = load('app_en.arb');
    ar = load('app_ar.arb');
  });

  test('مجموعة المفاتيح متطابقة في الملفين', () {
    final enKeys = messageKeys(en);
    final arKeys = messageKeys(ar);
    expect(
      enKeys.difference(arKeys).toList()..sort(),
      isEmpty,
      reason: 'مفاتيح في الإنجليزية بلا مقابل عربي',
    );
    expect(
      arKeys.difference(enKeys).toList()..sort(),
      isEmpty,
      reason: 'مفاتيح في العربية بلا مقابل إنجليزي',
    );
  });

  test('لا نص فارغ في أي من اللغتين', () {
    for (final MapEntry(:key, :value) in {...en, ...ar}.entries) {
      if (key.startsWith('@')) continue;
      expect(en[key], isNotNull, reason: 'قيمة إنجليزية مفقودة: $key');
      expect(ar[key], isNotNull, reason: 'قيمة عربية مفقودة: $key');
      expect((en[key] as String).trim(), isNotEmpty, reason: 'EN فارغ: $key');
      expect((ar[key] as String).trim(), isNotEmpty, reason: 'AR فارغ: $key');
      expect(value, isNotNull);
    }
  });

  test('معاملات كل مفتاح متطابقة بين اللغتين', () {
    for (final key in messageKeys(en)) {
      if (!ar.containsKey(key)) continue; // يغطيه الاختبار الأول
      expect(
        placeholdersOf(ar[key] as String),
        placeholdersOf(en[key] as String),
        reason: 'معاملات مختلفة في المفتاح "$key" — '
            'EN: ${en[key]} · AR: ${ar[key]}',
      );
    }
  });

  /// **الكتلة مطلوبة في القالب (`app_en.arb`) وحده** — تحقُّقٌ من سلوك
  /// `gen-l10n` لا من تخمين: `resultsFound` صيغة جمع في اللغتين وكتلته
  /// في الإنجليزية فقط، والتوليد يمرّ. اشتراطها في العربية أيضاً كان
  /// يُسقط الاختبار على ملفات **سليمة**.
  test('كل مفتاح بصيغة جمع له كتلة @ في القالب الإنجليزي', () {
    for (final key in messageKeys(en)) {
      final isPlural = (en[key] as String).contains(', plural,') ||
          ((ar[key] as String?) ?? '').contains(', plural,');
      if (!isPlural) continue;
      expect(en['@$key'], isNotNull,
          reason: 'صيغة جمع بلا كتلة @$key في app_en.arb — '
              'gen-l10n لن يعرف نوع المعامل');
    }
  });

  /// **حارس الرخصة (فتح المصدر 2026-09-09).**
  ///
  /// كانت شاشة «حول» تقول «جميع الحقوق محفوظة» — وهو نقيض GPL-3.0
  /// حرفياً: الرخصة تمنح النسخ والتعديل وإعادة النشر، والجملة تمنعها.
  /// أي عودة لهذا الادّعاء في أي نصّ تسقط هنا.
  test('لا ادّعاء بحفظ كل الحقوق يناقض GPL', () {
    for (final name in ['app_en.arb', 'app_ar.arb']) {
      final values = load(name).entries
          .where((e) => !e.key.startsWith('@'))
          .map((e) => e.value.toString().toLowerCase());
      for (final v in values) {
        expect(v.contains('all rights reserved'), isFalse,
            reason: 'نصّ يناقض GPL في $name');
        expect(v.contains('جميع الحقوق محفوظة'), isFalse,
            reason: 'نصّ يناقض GPL في $name');
      }
    }
  });

  /// الرخصة تتوقّع أن يجد المستخدم اسمها ونفي الضمان **داخل البرنامج**.
  test('نصوص الرخصة موجودة وتسمّيها', () {
    for (final name in ['app_en.arb', 'app_ar.arb']) {
      final arb = load(name);
      expect(arb['licensedUnder'].toString(), contains('GPL-3.0'),
          reason: name);
      expect(arb['copyright'].toString(), contains('2026'), reason: name);
      expect(arb['notAffiliated'].toString(), contains('MeTube'),
          reason: name);
      expect(arb['noWarranty'], isNotNull, reason: name);
    }
  });
}
