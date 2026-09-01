import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/features/library/library_models.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart' show MTMediaLocation;

void main() {
  final items = [
    LibraryItem(
      canonicalUrl: 'https://youtu.be/aaaaaaaaaaa',
      title: 'خطبة الجمعة',
      timestamp: DateTime(2026, 9, 1),
      sizeBytes: 300,
      onServer: true,
    ),
    LibraryItem(
      canonicalUrl: 'https://youtu.be/bbbbbbbbbbb',
      title: 'أنشودة الصباح',
      timestamp: DateTime(2026, 8, 1),
      sizeBytes: 100,
      onServer: true,
      localPath: '/x/a.mp3',
      isAudio: true,
      favorite: true,
    ),
    LibraryItem(
      canonicalUrl: 'https://vimeo.com/1',
      title: 'وثائقي البحار',
      timestamp: DateTime(2026, 7, 1),
      sizeBytes: 200,
      localPath: '/x/b.mp4',
      tags: const ['وثائقي'],
    ),
  ];

  group('buildLibraryView — منطق المكتبة الموحدة (م-13/م-14)', () {
    test('الافتراضي: الكل بالأحدث أولاً', () {
      final result = buildLibraryView(items);
      expect(result.map((i) => i.title).first, 'خطبة الجمعة');
      expect(result, hasLength(3));
    });

    test('مرشح المفضلة ♥ (م-36)', () {
      final result = buildLibraryView(items, scope: LibraryScope.favorites);
      expect(result.single.title, 'أنشودة الصباح');
    });

    test('مرشح دون اتصال / سيرفر', () {
      expect(buildLibraryView(items, scope: LibraryScope.offline),
          hasLength(2));
      expect(buildLibraryView(items, scope: LibraryScope.onServer),
          hasLength(2));
    });

    test('مرشح النوع صوت/فيديو', () {
      expect(
          buildLibraryView(items, type: MediaTypeFilter.audio), hasLength(1));
      expect(
          buildLibraryView(items, type: MediaTypeFilter.video), hasLength(2));
    });

    test('البحث الحي بالعنوان', () {
      expect(buildLibraryView(items, query: 'أنشودة').single.isAudio, isTrue);
      expect(buildLibraryView(items, query: 'غير موجود'), isEmpty);
    });

    test('تصفية وسم', () {
      expect(buildLibraryView(items, tag: 'وثائقي').single.title,
          'وثائقي البحار');
    });

    test('الفرز بالحجم والاسم', () {
      expect(
          buildLibraryView(items, sort: LibrarySort.largest)
              .first
              .sizeBytes,
          300);
      expect(buildLibraryView(items, sort: LibrarySort.nameAZ).first.title,
          'أنشودة الصباح');
    });

    test('شارة المكان (م-13)', () {
      expect(items[0].location, MTMediaLocation.onServer);
      expect(items[1].location, MTMediaLocation.both);
      expect(items[2].location, MTMediaLocation.offline);
    });
  });

  group('LibraryItem.fromHistory', () {
    test('كشف الصوت من quality=audio', () {
      final item = LibraryItem.fromHistory(HistoryItem.fromJson({
        'url': 'https://soundcloud.com/a/t',
        'title': 'مقطع',
        'quality': 'audio',
        'status': 'finished',
      }));
      expect(item.isAudio, isTrue);
      expect(item.onServer, isTrue);
    });

    test('fromOfflineOnly يستمد العنوان من اسم الملف', () {
      final item = LibraryItem.fromOfflineOnly(
          'https://youtu.be/ccccccccccc',
          '/storage/emulated/0/Download/MeTube_Super/درس التجويد_120000.mp4');
      expect(item.title, 'درس التجويد_120000');
      expect(item.isAudio, isFalse);
      expect(item.location, MTMediaLocation.offline);
    });
  });
}
