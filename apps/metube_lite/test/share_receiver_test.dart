import 'dart:async';

import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/features/home/reception.dart';

/// The Dart half of receiving a share. The native inbox (`ShareInbox.kt`)
/// holds a new share until it is taken, and calls `arrived` when one lands
/// on a running app; it is simulated here by a list that `take` empties.
///
/// What the native half decides (that a rebuilt activity's old share is not
/// a new one) is checked on a device: share a link with the app closed,
/// send the app to the background, `adb shell am kill <package>`, then share
/// another link. The sheet must show the second link, and opening the app
/// from its icon afterwards must show no sheet at all.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = ShareReceiver.channel;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<String> inbox;
  late Completer<void>? takeGate;
  late List<List<String>> delivered;
  late List<String> logs;

  /// The platform's half of `arrived`: a share has landed.
  Future<void> arrive(String text) async {
    inbox = [text];
    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(const MethodCall('arrived')),
      (_) {},
    );
  }

  setUp(() {
    inbox = [];
    takeGate = null;
    delivered = [];
    logs = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'take') return null;
      await takeGate?.future;
      final taken = inbox;
      inbox = [];
      return taken;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    channel.setMethodCallHandler(null);
  });

  ShareReceiver build() =>
      ShareReceiver(onUrls: delivered.add, onLog: logs.add);

  test('a share waiting before the shell listens is delivered', () async {
    inbox = ['https://youtu.be/dQw4w9WgXcQ'];
    final receiver = build();
    addTearDown(receiver.dispose);
    await receiver.start();

    expect(delivered, hasLength(1));
    expect(delivered.single.single, contains('dQw4w9WgXcQ'));
  });

  test(
    'a share arriving while the first take is in flight is not lost',
    () async {
      takeGate = Completer<void>();
      final receiver = build();
      addTearDown(receiver.dispose);
      final started = receiver.start();

      // The first take has already emptied the inbox and is waiting; the new
      // share lands now, and its own `arrived` must take it.
      final arrived = arrive('https://youtu.be/bbbbbbbbbbb');
      takeGate!.complete();
      await started;
      await arrived;

      expect(delivered.expand((b) => b), [contains('bbbbbbbbbbb')]);
    },
  );

  test('a share on a running app is taken when it arrives', () async {
    final receiver = build();
    addTearDown(receiver.dispose);
    await receiver.start();
    expect(delivered, isEmpty, reason: 'nothing was shared');

    await arrive('look at this https://youtu.be/aaaaaaaaaaa');

    expect(delivered.single.single, 'https://youtu.be/aaaaaaaaaaa');
  });

  test('the same batch twice is delivered once', () async {
    final receiver = build();
    addTearDown(receiver.dispose);
    await receiver.start();

    await arrive('https://youtu.be/aaaaaaaaaaa');
    await arrive('https://youtu.be/aaaaaaaaaaa');

    expect(delivered, hasLength(1), reason: 'otherwise two sheets stack');
    expect(logs.where((l) => l.startsWith('share duplicate')), hasLength(1));
  });

  // Field report 2026-10-15: sharing a link again after closing its sheet
  // did nothing at all, because it matched the last link received.
  test('the same link shared again later gets through', () async {
    var now = DateTime(2026, 10, 15, 13);
    final receiver = ShareReceiver(
      onUrls: delivered.add,
      onLog: logs.add,
      clock: () => now,
    );
    addTearDown(receiver.dispose);
    await receiver.start();

    await arrive('https://youtu.be/aaaaaaaaaaa');
    now = now.add(const Duration(seconds: 1));
    await arrive('https://youtu.be/aaaaaaaaaaa');
    expect(delivered, hasLength(1), reason: 'a double delivery');

    now = now.add(ShareReceiver.repeatWindow);
    await arrive('https://youtu.be/aaaaaaaaaaa');
    expect(delivered, hasLength(2), reason: 'a person sharing it again');
  });

  test('two different links both get through', () async {
    final receiver = build();
    addTearDown(receiver.dispose);
    await receiver.start();

    await arrive('https://youtu.be/aaaaaaaaaaa');
    await arrive('https://youtu.be/bbbbbbbbbbb');

    expect(delivered, hasLength(2));
  });

  test('several links in one share arrive as one batch', () async {
    final receiver = build();
    addTearDown(receiver.dispose);
    await receiver.start();

    await arrive('https://youtu.be/aaaaaaaaaaa\nhttps://youtu.be/bbbbbbbbbbb');

    expect(delivered.single, hasLength(2));
  });

  test('text with no link delivers nothing', () async {
    final receiver = build();
    addTearDown(receiver.dispose);
    await receiver.start();

    await arrive('just some words');

    expect(delivered, isEmpty);
  });

  test('every reception leaves a trace in the log', () async {
    final receiver = build();
    addTearDown(receiver.dispose);
    await receiver.start();

    await arrive('https://youtu.be/aaaaaaaaaaa');

    expect(logs.any((l) => l.startsWith('share received: 1')), isTrue);
  });

  test('a teardown during the take delivers nothing', () async {
    inbox = ['https://youtu.be/aaaaaaaaaaa'];
    takeGate = Completer<void>();
    final receiver = build();
    final started = receiver.start();
    receiver.dispose();
    takeGate!.complete();
    await started;

    await arrive('https://youtu.be/bbbbbbbbbbb');
    expect(delivered, isEmpty);
  });

  test('no native side is not an error', () async {
    messenger.setMockMethodCallHandler(channel, null);
    final receiver = build();
    addTearDown(receiver.dispose);

    await expectLater(receiver.start(), completes);
    expect(delivered, isEmpty);
  });
}
