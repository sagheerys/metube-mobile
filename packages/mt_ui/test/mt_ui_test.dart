import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

void main() {
  group('mtTheme — درس surfaceContainer*', () {
    for (final variant in MTVariant.values) {
      for (final brightness in Brightness.values) {
        test('${variant.name}/${brightness.name}: الأدوار الخمسة معينة ومتمايزة',
            () {
          final scheme = mtTheme(variant, brightness).colorScheme;
          final ramp = {
            scheme.surfaceContainerLowest,
            scheme.surfaceContainerLow,
            scheme.surfaceContainer,
            scheme.surfaceContainerHigh,
            scheme.surfaceContainerHighest,
          };
          expect(ramp, hasLength(5),
              reason: 'أي تطابق يعني سقوطاً لرماديات M3 الافتراضية');
          expect(scheme.surface, MTPalette.of(variant, brightness).bg);
        });
      }
    }

    test('لون الفعل: وهج لـ Super وبترولي لـ Lite (سجل §4)', () {
      expect(mtTheme(MTVariant.superApp, Brightness.light).colorScheme.primary,
          const Color(0xFFC25E2E));
      expect(mtTheme(MTVariant.superApp, Brightness.dark).colorScheme.primary,
          const Color(0xFFE0784A));
      expect(mtTheme(MTVariant.lite, Brightness.light).colorScheme.primary,
          const Color(0xFF2F6D74));
      expect(mtTheme(MTVariant.lite, Brightness.dark).colorScheme.primary,
          const Color(0xFF6FB3BA));
    });

    test('ليلاً النص فوق لون الفعل داكن لا أبيض (سجل §4)', () {
      for (final variant in MTVariant.values) {
        final onAccent =
            MTPalette.of(variant, Brightness.dark).onAccent;
        expect(onAccent.computeLuminance(), lessThan(0.1));
      }
    });

    test('المفضلة قرمزي مستقل عن لوني الفعل', () {
      for (final variant in MTVariant.values) {
        final p = MTPalette.of(variant, Brightness.light);
        expect(p.favorite, const Color(0xFFA83A3A));
        expect(p.favorite, isNot(p.accent));
      }
    });
  });

  group('MTGalleryScreen — بوابة 3', () {
    Widget host(MTVariant variant, Brightness brightness,
            TextDirection direction) =>
        MaterialApp(
          theme: mtTheme(variant, brightness),
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          locale: Locale(direction == TextDirection.rtl ? 'ar' : 'en'),
          home: Directionality(
            textDirection: direction,
            child: const MTGalleryScreen(),
          ),
        );

    for (final variant in MTVariant.values) {
      for (final brightness in Brightness.values) {
        for (final direction in TextDirection.values) {
          testWidgets(
              'يرسم بلا أخطاء: ${variant.name}/${brightness.name}/${direction.name}',
              (tester) async {
            // سطح طويل حتى تُبنى كل أقسام القائمة الكسولة
            tester.view.physicalSize = const Size(800, 3600);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(host(variant, brightness, direction));
            await tester.pump(const Duration(milliseconds: 50));
            expect(tester.takeException(), isNull);
            expect(find.byType(MTGalleryScreen), findsOneWidget);
            expect(find.byType(MTMediaCard), findsWidgets);
            expect(find.byType(MTDownloadProgressCard), findsNWidgets(2));
          });
        }
      }
    }
  });

  group('MTMediaCard', () {
    testWidgets('نقرة القلب تستدعي التبديل', (tester) async {
      var toggled = false;
      await tester.pumpWidget(MaterialApp(
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        // البطاقة تقرأ الترجمة لتلميحات الأزرار ووصف قارئ الشاشة
        // (تدقيق 8.1) — فتحتاج المندوبين مثل أي شاشة حقيقية.
        locale: const Locale('ar'),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        home: Scaffold(
          body: MTMediaCard(
            title: 'عنوان',
            favorite: true,
            onFavoriteToggle: () => toggled = true,
          ),
        ),
      ));
      await tester.tap(find.byIcon(Icons.favorite_rounded));
      expect(toggled, isTrue);
    });
  });

  group('MTLocalizations', () {
    test('عربي وإنجليزي مدعومان', () {
      expect(
        MTLocalizations.supportedLocales.map((l) => l.languageCode),
        containsAll(['ar', 'en']),
      );
    });

    /// **مصطاد بالفحص اليدوي على الجهاز 2026-09-08**: حوار حذف القائمة
    /// كان يعرض `حذف \"Single Releases\"؟` بشرطتين مائلتين ظاهرتين —
    /// لأن الاقتباس في arb كُتب `\\\"` فيفكّه JSON إلى شرطة + اقتباس.
    /// لا يكشفه `analyze` ولا حارس التكافؤ: الملف JSON سليم والمفتاح
    /// مترجَم في اللغتين. **العين وحدها تراه** — وهذا الحارس يغني عنها.
    test('لا شرطة مائلة ظاهرة في نصوص التأكيد', () async {
      for (final code in ['ar', 'en']) {
        final l10n = await MTLocalizations.delegate.load(Locale(code));
        for (final text in [
          l10n.deletePlaylistConfirm('س'),
          l10n.deleteVideoConfirm('س'),
          l10n.deleteTagConfirm('س'),
        ]) {
          expect(text, isNot(contains(r'\')), reason: '[$code] $text');
        }
      }
    });
  });
}
