import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/features/batch/batch_offline_saver.dart';
import 'package:mt_core/mt_core.dart';

/// **طلب المالك 2026-09-03:** «حالياً لا يحمّلها على الجهاز وإنما على
/// السيرفر». Super يضيف ولا يسحب (ر-2)، فهذا المُنفِّذ يطبّق «إتاحة دون
/// اتصال» (م-17) على أعضاء الدفعة التي طلبها المالك — وحدها.
void main() {
  DownloadTask done(String id, {String? url}) => DownloadTask(
    id: id,
    inputUrl: url ?? 'https://sc/$id',
    quality: Quality.audio,
    canonicalUrl: url ?? 'https://sc/$id',
    serverFilename: '$id.m4a',
    title: id,
    phase: TaskPhase.completed,
    isBatchMember: true,
  );

  test('يُسحب أعضاء الدفعة المطلوبة وحدهم', () async {
    final pulled = <String>[];
    final saver = BatchOfflineSaver(pull: (t) async => pulled.add(t.id));
    saver.want(['a', 'b']);

    saver.onFinished(done('a'));
    saver.onFinished(done('c')); // ليس من الدفعة — تحميل مفرد بجانبها
    saver.onFinished(done('b'));
    await saver.idle;

    expect(pulled, ['a', 'b']);
  });

  test('السحب متسلسل — لا 400 تنزيل معاً', () async {
    var active = 0;
    var peak = 0;
    final saver = BatchOfflineSaver(
      pull: (t) async {
        active++;
        peak = peak > active ? peak : active;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        active--;
      },
    );
    saver.want(['a', 'b', 'c']);
    for (final id in ['a', 'b', 'c']) {
      saver.onFinished(done(id));
    }
    await saver.idle;

    expect(peak, 1);
  });

  test('فشل عنصر لا يوقف بقية الألبوم', () async {
    final pulled = <String>[];
    final errors = <Object>[];
    final saver = BatchOfflineSaver(
      pull: (t) async {
        if (t.id == 'b') throw const NetworkException('offline');
        pulled.add(t.id);
      },
      onError: errors.add,
    );
    saver.want(['a', 'b', 'c']);
    for (final id in ['a', 'b', 'c']) {
      saver.onFinished(done(id));
    }
    await saver.idle;

    expect(pulled, ['a', 'c']);
    expect(errors, hasLength(1));
  });

  test('العضو الساقط لا يبقى منتظراً للأبد', () async {
    final saver = BatchOfflineSaver(pull: (_) async {});
    saver.want(['a', 'b']);
    saver.forget('a');
    expect(saver.pendingCount, 1);

    saver.onFinished(done('a')); // لن يُسحب: نُسي عمداً
    await saver.idle;
    expect(saver.pendingCount, 1);
  });

  test('مهمة بلا canonicalUrl لا تُسحب (لا مفتاح لفهرستها)', () async {
    final pulled = <String>[];
    final saver = BatchOfflineSaver(pull: (t) async => pulled.add(t.id));
    saver.want(['a']);
    saver.onFinished(
      DownloadTask(
        id: 'a',
        inputUrl: 'https://sc/a',
        quality: Quality.audio,
        phase: TaskPhase.completed,
        isBatchMember: true,
      ),
    );
    await saver.idle;

    expect(pulled, isEmpty);
  });
}
