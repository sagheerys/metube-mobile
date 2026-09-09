import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/features/shared/async_view.dart';

/// **The "library flicker" guard (field report 2026-09-03).**
///
/// The first test is the one that failed on `whenData`: a loading state
/// carrying earlier data was converted into an empty `AsyncLoading`, so the
/// screen replaced the library with a spinner throughout every poll.
void main() {
  // **`isRefresh: false` is not a detail**: it is what Riverpod builds when
  // a lower provider is invalidated, rather than when this provider is
  // itself reloaded, and it is the only one that stays an `AsyncLoading`
  // still carrying the value, which is exactly what `whenData` emptied.
  // Proven with a probe against Riverpod:
  // derived = AsyncLoading<List<int>>(value: [1, 2, 3])
  // whenData => AsyncLoading<int>()   <- hasValue = false
  test(
    'loading over previous data, a lower provider invalidated, keeps the value',
    () {
      const previous = AsyncData<List<int>>([1, 2, 3]);
      final loading = const AsyncLoading<List<int>>().copyWithPrevious(
        previous,
        isRefresh: false,
      );
      expect(
        loading,
        isA<AsyncLoading<List<int>>>(),
        reason: 'شرط الاختبار نفسه: الحالة تحميل لا بيانات-تُحدَّث',
      );

      final view = asyncViewOf(loading, (items) => items.length);

      expect(view.valueOrNull, 3, reason: 'whenData كانت تعيد null هنا');
    },
  );

  test('reloading this very provider keeps the value too', () {
    const previous = AsyncData<List<int>>([1, 2, 3]);
    final refreshing = const AsyncLoading<List<int>>().copyWithPrevious(
      previous,
    );
    expect(asyncViewOf(refreshing, (items) => items.length).valueOrNull, 3);
  });

  test('complete data builds as usual', () {
    final view = asyncViewOf(
      const AsyncData<List<int>>([1, 2]),
      (items) => items.length,
    );
    expect(view.valueOrNull, 2);
    expect(view.isLoading, isFalse);
  });

  test('a first load with no data shows loading', () {
    final view = asyncViewOf(
      const AsyncLoading<List<int>>(),
      (items) => items.length,
    );
    expect(view.valueOrNull, isNull);
    expect(view.isLoading, isTrue);
  });

  test('an error with no data shows the error, not a spinner forever', () {
    final view = asyncViewOf(
      AsyncError<List<int>>('boom', StackTrace.empty),
      (items) => items.length,
    );
    expect(view.hasError, isTrue);
    expect(view.error, 'boom');
  });

  test('an error over previous data: the data wins', () {
    const previous = AsyncData<List<int>>([9]);
    final failed = AsyncError<List<int>>(
      'boom',
      StackTrace.empty,
    ).copyWithPrevious(previous);
    final view = asyncViewOf(failed, (items) => items.length);
    expect(view.valueOrNull, 1);
  });
}
