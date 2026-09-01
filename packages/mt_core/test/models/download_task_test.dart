import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

void main() {
  group('DownloadTask', () {
    test('معرف uuid تلقائي فريد', () {
      final a = DownloadTask(inputUrl: 'u', quality: Quality.best);
      final b = DownloadTask(inputUrl: 'u', quality: Quality.best);
      expect(a.id, isNotEmpty);
      expect(a.id, isNot(b.id));
    });

    test('copyWith يحفظ الهوية ويحدث المرحلة', () {
      final task = DownloadTask(inputUrl: 'u', quality: Quality.audio);
      final updated = task.copyWith(
        phase: TaskPhase.polling,
        canonicalUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        progress: 0.5,
      );
      expect(updated.id, task.id);
      expect(updated.createdAt, task.createdAt);
      expect(updated.quality, Quality.audio);
      expect(updated.phase, TaskPhase.polling);
      expect(updated.progress, 0.5);
      expect(task.phase, TaskPhase.queued, reason: 'الأصل لا يتغير');
    });

    test('effectiveUrl يفضّل المحلول', () {
      final task = DownloadTask(inputUrl: 'https://vt.tiktok.com/xyz/',
          quality: Quality.best);
      expect(task.effectiveUrl, 'https://vt.tiktok.com/xyz/');
      expect(task.copyWith(resolvedUrl: 'https://www.tiktok.com/@u/video/1')
          .effectiveUrl, 'https://www.tiktok.com/@u/video/1');
    });

    test('isFinished للحالات النهائية فقط', () {
      final task = DownloadTask(inputUrl: 'u', quality: Quality.best);
      expect(task.isFinished, isFalse);
      expect(task.copyWith(phase: TaskPhase.completed).isFinished, isTrue);
      expect(task.copyWith(phase: TaskPhase.failed).isFinished, isTrue);
      expect(task.copyWith(phase: TaskPhase.cancelled).isFinished, isTrue);
      expect(task.copyWith(phase: TaskPhase.pulling).isFinished, isFalse);
    });
  });
}
