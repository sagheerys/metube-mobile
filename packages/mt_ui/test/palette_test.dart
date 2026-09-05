import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// **حارس المشغل المصغر (قرار المالك 2026-09-05)**: العكس فكرة نهارية
/// — شريط داكن تحت واجهة كريمية. ليلاً كان يصير شريطاً فاتحاً ساطعاً
/// تحت شاشة سوداء، وهجٌ في غرفة مظلمة.
void main() {
  for (final variant in MTVariant.values) {
    final day = MTPalette.of(variant, Brightness.light);
    final night = MTPalette.of(variant, Brightness.dark);

    test('نهاراً معكوس — ${variant.name}', () {
      expect(day.miniBg, day.ink);
      expect(day.miniInk, day.bg);
      expect(day.night, isFalse);
    });

    test('ليلاً متّسق مع الثيم — ${variant.name}', () {
      expect(night.night, isTrue);
      expect(night.miniBg, night.card, reason: 'لا انقلاب ليلي');
      expect(night.miniInk, night.ink);
      // ولا يصير الشريط أفتح من أرضية الشاشة نفسها.
      expect(night.miniBg.computeLuminance(),
          lessThan(night.miniInk.computeLuminance()));
    });
  }
}
