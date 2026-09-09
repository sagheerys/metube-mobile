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
      final task = DownloadTask(
        inputUrl: 'https://vt.tiktok.com/xyz/',
        quality: Quality.best,
      );
      expect(task.effectiveUrl, 'https://vt.tiktok.com/xyz/');
      expect(
        task
            .copyWith(resolvedUrl: 'https://www.tiktok.com/@u/video/1')
            .effectiveUrl,
        'https://www.tiktok.com/@u/video/1',
      );
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

  /// الشريط المُجمِّع أعلى المكتبة حين تتعدد التحميلات (بلاغ المالك
  /// 2026-09-03) — المنتظِرة **تُحسب صفراً لا تُستبعد**.
  group('averageTaskProgress', () {
    DownloadTask make(TaskPhase phase, double progress) => DownloadTask(
      inputUrl: 'u',
      quality: Quality.best,
    ).copyWith(phase: phase, progress: progress);

    test('فارغة ⇒ null', () => expect(averageTaskProgress(const []), isNull));

    test('كلها بلا تقدم معروف ⇒ null (شريط غير محدد)', () {
      expect(
        averageTaskProgress([
          make(TaskPhase.queued, 0),
          make(TaskPhase.waitingForNetwork, 0.9),
        ]),
        isNull,
      );
    });

    test('المنتظِرة تخفض المتوسط بدل أن تُستبعد', () {
      // واحدة على 90٪ واثنتان في الطابور ⇒ 30٪ لا 90٪.
      final average = averageTaskProgress([
        make(TaskPhase.pulling, 0.9),
        make(TaskPhase.queued, 0),
        make(TaskPhase.queued, 0),
      ]);
      expect(average, closeTo(0.3, 0.001));
    });

    test('متوسط عادي', () {
      expect(
        averageTaskProgress([
          make(TaskPhase.polling, 0.25),
          make(TaskPhase.pulling, 0.75),
        ]),
        closeTo(0.5, 0.001),
      );
    });
  });
}
