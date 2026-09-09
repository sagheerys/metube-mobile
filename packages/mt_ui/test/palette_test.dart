import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// **The mini player guard** (decision 2026-09-05): inversion is a
/// daylight idea, a dark bar under a cream interface. At night it became a
/// bright pale bar under a black screen, a glare in a dark room.
void main() {
  for (final variant in MTVariant.values) {
    final day = MTPalette.of(variant, Brightness.light);
    final night = MTPalette.of(variant, Brightness.dark);

    test('inverted by day: ${variant.name}', () {
      expect(day.miniBg, day.ink);
      expect(day.miniInk, day.bg);
      expect(day.night, isFalse);
    });

    test('consistent with the theme at night: ${variant.name}', () {
      expect(night.night, isTrue);
      expect(night.miniBg, night.card, reason: 'لا انقلاب ليلي');
      expect(night.miniInk, night.ink);
      // And the bar never ends up lighter than the screen ground itself.
      expect(
        night.miniBg.computeLuminance(),
        lessThan(night.miniInk.computeLuminance()),
      );
    });
  }
}
