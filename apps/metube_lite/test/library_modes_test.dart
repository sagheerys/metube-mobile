import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/di.dart';
import 'package:metube_lite/features/downloads_library/artwork_view.dart';
import 'package:metube_lite/features/downloads_library/library_providers.dart';
import 'package:metube_lite/features/downloads_library/local_item.dart';
import 'package:mt_core/mt_core.dart';

/// نظير `apps/metube_super/test/library_modes_test.dart` — الوضع الرابع
/// وصل التطبيقين معاً (طلب المالك 2026-09-08)، فحارسه في كليهما.
void main() {
  late MemoryKeyValueStore store;

  setUp(() => store = MemoryKeyValueStore());

  Future<LibraryViewOptions> restored() async {
    final c = ProviderContainer(overrides: [
      keyValueStoreProvider.overrideWithValue(store),
      prefsMutexProvider.overrideWithValue(PrefsMutex()),
    ]);
    addTearDown(c.dispose);
    c.read(libraryViewProvider);
    await pumpEventQueue();
    return c.read(libraryViewProvider);
  }

  test('لا شيء محفوظ ⇒ القائمة', () async {
    expect((await restored()).mode, LibraryViewMode.list);
  });

  /// **الحارس**: من يحدّث التطبيق وهو على «شبكي» يجب أن يجده كما تركه.
  test('هجرة من المفتاحين القديمين', () async {
    await store.setBool('library_grid_view', true);
    expect((await restored()).mode, LibraryViewMode.grid);
  });

  test('المفتاح الجديد يغلب القديمين', () async {
    await store.setBool('library_grid_view', true);
    await store.setString('library_view_mode', 'cards');
    final options = await restored();
    expect(options.cards, isTrue);
    expect(options.grid, isFalse);
  });

  testWidgets('عرض الفك يرتفع بالارتفاع حين يفرضه cover', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(devicePixelRatio: 2),
      child: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }),
    ));
    expect(mtDecodeWidth(ctx, 98, 62), (62 * 16 / 9 * 2).ceil());
    expect(mtDecodeWidth(ctx, 210), 420);
  });
}
