import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/library/artwork_view.dart';
import 'package:metube_super/features/library/library_models.dart';
import 'package:metube_super/features/library/library_providers.dart';
import 'package:metube_super/features/library/widgets/library_chips.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// **الوضع الرابع ومرشح المنصة** (طلب المالك 2026-09-08).
///
/// ثلاثة حرّاس مستقلة: هجرة وضع العرض من المفتاحين القديمين، وحساب
/// عرض فكّ الترميز، وظهور المنصة المفعّلة في الصف الأول.
void main() {
  late MemoryKeyValueStore store;

  setUp(() => store = MemoryKeyValueStore());

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<LibraryViewOptions> restored(ProviderContainer c) async {
    c.read(libraryViewProvider);
    await pumpEventQueue();
    return c.read(libraryViewProvider);
  }

  group('وضع العرض — أربعة أوضاع بمفتاح واحد', () {
    test('لا شيء محفوظ ⇒ القائمة', () async {
      expect((await restored(container())).mode, LibraryViewMode.list);
    });

    /// **الحارس**: من يحدّث التطبيق وهو على «شبكي» يجب أن يجده كما تركه.
    test('هجرة من المفتاح القديم library_grid_view', () async {
      await store.setBool('library_grid_view', true);
      final options = await restored(container());
      expect(options.mode, LibraryViewMode.grid);
      expect(options.grid, isTrue);
      expect(options.compact, isFalse);
    });

    test('هجرة من المفتاح القديم library_compact_view', () async {
      await store.setBool('library_compact_view', true);
      expect((await restored(container())).mode, LibraryViewMode.compact);
    });

    test('المفتاح الجديد يغلب القديمين', () async {
      await store.setBool('library_grid_view', true);
      await store.setString('library_view_mode', 'cards');
      final options = await restored(container());
      expect(options.mode, LibraryViewMode.cards);
      expect(options.cards, isTrue);
      expect(options.grid, isFalse);
    });

    test('التبديل يُحفظ بالاسم لا بعلم', () async {
      final c = container();
      await restored(c);
      await c.read(libraryViewProvider.notifier).setMode(LibraryViewMode.cards);
      expect(await store.getString('library_view_mode'), 'cards');
      expect(c.read(libraryViewProvider).mode, LibraryViewMode.cards);
    });
  });

  group('عرض فكّ الترميز', () {
    late BuildContext ctx;

    Future<void> host(WidgetTester tester, double dpr) => tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(devicePixelRatio: dpr),
        child: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );

    testWidgets('العرض المنطقي × كثافة الشاشة', (tester) async {
      await host(tester, 3);
      expect(mtDecodeWidth(ctx, 210), 630);
    });

    /// **الحارس**: صندوق 98×62 أعرض نسبةً من 16:9، فـ`cover` يشتق
    /// المقياس من الارتفاع. الفك عند 98 وحده يعطي صورة ارتفاعها 55
    /// تُمطّ إلى 62 — ضبابية مضافة بأيدينا.
    testWidgets('الارتفاع يرفع العرض حين يفرضه cover', (tester) async {
      await host(tester, 2);
      expect(mtDecodeWidth(ctx, 98, 62), (62 * 16 / 9 * 2).ceil());
      expect(mtDecodeWidth(ctx, 98, 62), greaterThan(98 * 2));
    });

    testWidgets('صندوق أطول من 16:9 لا يُرفع عرضه', (tester) async {
      await host(tester, 2);
      expect(mtDecodeWidth(ctx, 300, 62), 600);
    });
  });

  group('رقاقة المنصة في الصف الأول', () {
    Widget app(List<LibraryItem> items) => ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(const SuperSettings()),
        libraryItemsProvider.overrideWith((ref) async => items),
      ],
      child: MaterialApp(
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        locale: const Locale('ar'),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        home: const Scaffold(body: LibraryFilterChips()),
      ),
    );

    final items = [
      LibraryItem(canonicalUrl: 'https://youtu.be/a', title: 'أ'),
      LibraryItem(canonicalUrl: 'https://vimeo.com/1', title: 'ب'),
    ];

    testWidgets('بلا منصة مختارة ⇒ لا رقاقة إضافية (لا صف ثالث)', (
      tester,
    ) async {
      await tester.pumpWidget(app(items));
      await tester.pumpAndSettle();
      expect(find.byType(InputChip), findsNothing);
    });

    /// **الحارس**: تصفيةٌ فعّالة مخبوءة خلف زر تجعل المكتبة تبدو ناقصة
    /// بلا سبب ظاهر — الرقاقة هي ما يجعلها مرئية وقابلة للإلغاء.
    testWidgets('المنصة المفعّلة تظهر رقاقةً تُزال بنقرة', (tester) async {
      await tester.pumpWidget(app(items));
      await tester.pumpAndSettle();
      final element = tester.element(find.byType(LibraryFilterChips));
      final container = ProviderScope.containerOf(element);
      container
          .read(libraryViewProvider.notifier)
          .setPlatform(MediaPlatform.youtube);
      await tester.pumpAndSettle();

      expect(find.text('YouTube'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(container.read(libraryViewProvider).platform, isNull);
      expect(find.byType(InputChip), findsNothing);
    });
  });
}
