import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **The two-language parity guard.**
///
/// Every interface string is written into `app_en.arb` and `app_ar.arb`
/// **together, in the same batch**. That used to be a written rule that
/// could be forgotten; this makes it a test that **fails** when a key is
/// missing from either file, when its placeholders differ, or when it is
/// left untranslated.
///
/// It is never disabled or bypassed: a one-legged key means an English
/// string shown to an Arabic-speaking family member, or an
/// `undefined_getter` crash at build time.
void main() {
  final dir = Directory('lib/src/l10n');

  Map<String, dynamic> load(String name) {
    final file = File('${dir.path}/$name');
    expect(file.existsSync(), isTrue, reason: 'ملف الترجمة مفقود: $name');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  /// The string keys only, without `@@locale` and without the `@key`
  /// metadata blocks.
  Set<String> messageKeys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  /// Placeholder names inside the text: `{percent}`, `{count}`. Plural
  /// forms are picked up from their branches so the two files match.
  Set<String> placeholdersOf(String value) =>
      RegExp(r'\{(\w+)\}').allMatches(value).map((m) => m.group(1)!).toSet();

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
        reason:
            'معاملات مختلفة في المفتاح "$key" — '
            'EN: ${en[key]} · AR: ${ar[key]}',
      );
    }
  });

  /// **The metadata block is required in the template (`app_en.arb`)
  /// only**, verified against `gen-l10n`'s actual behaviour rather than
  /// assumed: `resultsFound` is a plural in both languages with its block
  /// in English alone, and generation passes. Requiring it in Arabic too
  /// used to fail the test on **healthy** files.
  test('كل مفتاح بصيغة جمع له كتلة @ في القالب الإنجليزي', () {
    for (final key in messageKeys(en)) {
      final isPlural =
          (en[key] as String).contains(', plural,') ||
          ((ar[key] as String?) ?? '').contains(', plural,');
      if (!isPlural) continue;
      expect(
        en['@$key'],
        isNotNull,
        reason:
            'صيغة جمع بلا كتلة @$key في app_en.arb — '
            'gen-l10n لن يعرف نوع المعامل',
      );
    }
  });

  /// **The licence guard** (open-sourcing, 2026-09-09).
  ///
  /// The About screen used to say "all rights reserved", which is the
  /// literal opposite of GPL-3.0: the licence grants copying, modification
  /// and redistribution, and that sentence forbids them. Any return of that
  /// claim in any string fails here.
  test('لا ادّعاء بحفظ كل الحقوق يناقض GPL', () {
    for (final name in ['app_en.arb', 'app_ar.arb']) {
      final values = load(name).entries
          .where((e) => !e.key.startsWith('@'))
          .map((e) => e.value.toString().toLowerCase());
      for (final v in values) {
        expect(
          v.contains('all rights reserved'),
          isFalse,
          reason: 'نصّ يناقض GPL في $name',
        );
        expect(
          v.contains('جميع الحقوق محفوظة'),
          isFalse,
          reason: 'نصّ يناقض GPL في $name',
        );
      }
    }
  });

  /// The licence expects the user to find its name and the warranty
  /// disclaimer **inside the program**.
  test('نصوص الرخصة موجودة وتسمّيها', () {
    for (final name in ['app_en.arb', 'app_ar.arb']) {
      final arb = load(name);
      expect(
        arb['licensedUnder'].toString(),
        contains('GPL-3.0'),
        reason: name,
      );
      expect(arb['copyright'].toString(), contains('2026'), reason: name);
      expect(arb['notAffiliated'].toString(), contains('MeTube'), reason: name);
      expect(arb['noWarranty'], isNotNull, reason: name);
    }
  });
}
