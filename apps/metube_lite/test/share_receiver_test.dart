import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/features/home/reception.dart';

/// **Field report 2026-09-08: "sometimes the download sheet only appears if
/// I try again".**
///
/// `start()` used to read the initial link **and then** subscribe to the
/// stream, and between the two awaits there was a window with no listener.
/// An app resting in the background has its link delivered straight to the
/// stream, so it fell into that window without a trace, and a retry then
/// succeeded because the subscription was in place.
///
/// The platform is simulated through the package's own two channels:
/// `getInitialMedia` is deliberately slow, and the event arrives during
/// that slowness, which is the moment that used to be lost.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methods = MethodChannel('receive_sharing_intent/messages');
  const events = EventChannel('receive_sharing_intent/events-media');
  final binding = TestDefaultBinaryMessengerBinding.instance;

  late Completer<void> initialGate;
  late List<List<String>> delivered;
  late List<String> logs;

  /// Pushes an event into the broadcast channel **with the platform's own
  /// encoding**: JSON text inside a success envelope, not a raw map (read
  /// from the package source, version 1.9.0).
  Future<void> emit(String text) async {
    final payload = const StandardMethodCodec().encodeSuccessEnvelope(
      jsonEncode([
        {'path': text, 'type': 'text'},
      ]),
    );
    await binding.defaultBinaryMessenger.handlePlatformMessage(
      events.name,
      payload,
      (_) {},
    );
  }

  setUp(() {
    initialGate = Completer<void>();
    delivered = [];
    logs = [];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(methods, (
      call,
    ) async {
      if (call.method == 'getInitialMedia') {
        // **Deliberately slow**: this is the window the event used to fall
        // into.
        await initialGate.future;
        return null;
      }
      return null;
    });
    // **No `setMockMessageHandler` here**: it replaces the channel receiver
    // that `EventChannel` registered on subscribing, so the event never
    // arrives. What is needed is to answer the outgoing `listen` and
    // `cancel` calls only.
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('receive_sharing_intent/events-media'),
      (call) async => null,
    );
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(methods, null);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('receive_sharing_intent/events-media'),
      null,
    );
  });

  ShareReceiver build() =>
      ShareReceiver(onUrls: delivered.add, onLog: logs.add);

  test('a link arriving before getInitialMedia finishes is not lost', () async {
    final receiver = build();
    addTearDown(receiver.dispose);
    final started = receiver.start();

    // The critical moment: the platform delivers the link while the first
    // await has not finished.
    await emit('https://youtu.be/dQw4w9WgXcQ');
    initialGate.complete();
    await started;

    // **The guard**: with the old ordering this list was empty.
    expect(
      delivered,
      hasLength(1),
      reason: 'الاشتراك يجب أن يسبق قراءة الرابط الأولي',
    );
    expect(delivered.single.single, contains('dQw4w9WgXcQ'));
  });

  test('the same batch twice is delivered once', () async {
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

  test('two different links both get through', () async {
    final receiver = build();
    addTearDown(receiver.dispose);
    final started = receiver.start();
    initialGate.complete();
    await started;

    await emit('https://youtu.be/aaaaaaaaaaa');
    await emit('https://youtu.be/bbbbbbbbbbb');

    expect(delivered, hasLength(2));
  });

  test('every reception leaves a trace in the log', () async {
    final receiver = build();
    addTearDown(receiver.dispose);
    final started = receiver.start();
    initialGate.complete();
    await started;

    await emit('https://youtu.be/aaaaaaaaaaa');

    expect(logs.any((l) => l.startsWith('share received: 1')), isTrue);
  });

  test('a teardown during the await delivers nothing', () async {
    final receiver = build();
    final started = receiver.start();
    receiver.dispose();
    initialGate.complete();
    await started;

    await emit('https://youtu.be/aaaaaaaaaaa');
    expect(delivered, isEmpty);
  });
}
