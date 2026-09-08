import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/features/home/reception.dart';

/// **بلاغ المالك 2026-09-08 — «أحياناً لا تظهر ورقة التحميل إلا بإعادة
/// المحاولة».**
///
/// كان `start()` يقرأ الرابط الأولي **ثم** يشترك في البثّ، وبين
/// الانتظارين نافذةٌ بلا مستمع. والتطبيق الساكن في الخلفية يُسلَّم
/// رابطه إلى البثّ مباشرة، فيسقط فيها بلا أثر — ثم تنجح إعادة المحاولة
/// لأن الاشتراك صار قائماً.
///
/// المنصة تُحاكى بقناتَي الحزمة نفسها: `getInitialMedia` بطيء عمداً،
/// والحدث يصل أثناء بطئه — وهي اللحظة التي كانت تضيع.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methods = MethodChannel('receive_sharing_intent/messages');
  const events = EventChannel('receive_sharing_intent/events-media');
  final binding = TestDefaultBinaryMessengerBinding.instance;

  late Completer<void> initialGate;
  late List<List<String>> delivered;
  late List<String> logs;

  /// يدفع حدثاً في قناة البثّ **بنفس ترميز المنصة**: نصّ JSON داخل
  /// مغلّف نجاح، لا خريطة خام (مقروء من مصدر الحزمة 1.9.0).
  Future<void> emit(String text) async {
    final payload = const StandardMethodCodec().encodeSuccessEnvelope(
      jsonEncode([
        {'path': text, 'type': 'text'},
      ]),
    );
    await binding.defaultBinaryMessenger
        .handlePlatformMessage(events.name, payload, (_) {});
  }

  setUp(() {
    initialGate = Completer<void>();
    delivered = [];
    logs = [];
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(methods, (call) async {
      if (call.method == 'getInitialMedia') {
        // **بطء مقصود**: هذه هي النافذة التي كان الحدث يسقط فيها.
        await initialGate.future;
        return null;
      }
      return null;
    });
    // **لا `setMockMessageHandler` هنا**: هي تستبدل مستقبِل القناة الذي
    // سجّله `EventChannel` عند الاشتراك، فلا يصل الحدث أبداً. المطلوب
    // الردّ على نداءي `listen`/`cancel` الصادرين فقط.
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('receive_sharing_intent/events-media'),
        (call) async => null);
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(methods, null);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('receive_sharing_intent/events-media'), null);
  });

  ShareReceiver build() => ShareReceiver(
        onUrls: delivered.add,
        onLog: logs.add,
      );

  test('رابط يصل قبل انتهاء getInitialMedia لا يضيع', () async {
    final receiver = build();
    addTearDown(receiver.dispose);
    final started = receiver.start();

    // اللحظة الحرجة: المنصة تسلّم الرابط والانتظار الأول لم ينتهِ بعد.
    await emit('https://youtu.be/dQw4w9WgXcQ');
    initialGate.complete();
    await started;

    // **الحارس**: بالترتيب القديم كانت هذه القائمة فارغة.
    expect(delivered, hasLength(1),
        reason: 'الاشتراك يجب أن يسبق قراءة الرابط الأولي');
    expect(delivered.single.single, contains('dQw4w9WgXcQ'));
  });

  test('نفس الدفعة مرتين ⇒ تسليم واحد', () async {
    final receiver = build();
    addTearDown(receiver.dispose);
    final started = receiver.start();
    initialGate.complete();
    await started;

    await emit('https://youtu.be/aaaaaaaaaaa');
    await emit('https://youtu.be/aaaaaaaaaaa');

    expect(delivered, hasLength(1), reason: 'وإلا ورقتان فوق بعضهما');
    expect(logs.where((l) => l.startsWith('share duplicate')), hasLength(1));
  });

  test('رابطان مختلفان يمرّان كلاهما', () async {
    final receiver = build();
    addTearDown(receiver.dispose);
    final started = receiver.start();
    initialGate.complete();
    await started;

    await emit('https://youtu.be/aaaaaaaaaaa');
    await emit('https://youtu.be/bbbbbbbbbbb');

    expect(delivered, hasLength(2));
  });

  test('كل استقبال يترك أثراً في السجل', () async {
    final receiver = build();
    addTearDown(receiver.dispose);
    final started = receiver.start();
    initialGate.complete();
    await started;

    await emit('https://youtu.be/aaaaaaaaaaa');

    expect(logs.any((l) => l.startsWith('share received: 1')), isTrue);
  });

  test('التفكيك أثناء الانتظار لا يسلّم شيئاً (م-1)', () async {
    final receiver = build();
    final started = receiver.start();
    receiver.dispose();
    initialGate.complete();
    await started;

    await emit('https://youtu.be/aaaaaaaaaaa');
    expect(delivered, isEmpty);
  });
}
