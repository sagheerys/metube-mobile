import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// **The device matrix**: a substitute for owning twenty phones.
///
/// The maintainer has two devices: the emulator (411x914 points) and a
/// Galaxy S22 Ultra (384x823). Everything else is never seen by any eye,
/// and the common breakage on Android is not in the logic but in **the
/// layout**: a shorter screen, or the system font enlarged for eyesight,
/// pushes content that used to fit outside its frame.
///
/// This matrix renders the widget across the critical sizes and text scales
/// and catches `RenderFlex overflowed` from Flutter's own engine, the error
/// that shows on a user's device as a yellow and black stripe and never
/// shows on the developer's.
class MTDevice {
  const MTDevice(this.name, this.size);

  final String name;
  final Size size;

  /// Sizes in logical points (dp), not pixels.
  static const List<MTDevice> all = [
    // The smallest realistic Android screen still receiving updates.
    MTDevice('صغير 320×534', Size(320, 534)),
    MTDevice('اقتصادي 360×640', Size(360, 640)),
    // The maintainer's actual device.
    MTDevice('جلاكسي S22 ألترا 384×823', Size(384, 823)),
    MTDevice('محاكي المشروع 411×914', Size(411, 914)),
    MTDevice('لوحي 800×1280', Size(800, 1280)),
  ];
}

/// Text scales: normal, the one common among older users, and Android's
/// accessibility ceiling.
const List<double> mtTextScales = [1.0, 1.3, 2.0];

/// Builds [child] at every size and every text scale, and fails at the
/// first overflow.
///
/// [maxScaleFor] allows a documented exception: some very small sizes at
/// 2.0x cannot hold any design, and the decision is then "waived", not
/// "hidden".
Future<void> expectNoOverflow(
  WidgetTester tester,
  Widget Function() build, {
  List<MTDevice> devices = MTDevice.all,
  List<double> scales = mtTextScales,
}) async {
  addTearDown(tester.view.reset);
  for (final device in devices) {
    for (final scale in scales) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = device.size;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: device.size,
            textScaler: TextScaler.linear(scale),
          ),
          child: build(),
        ),
      );
      await tester.pumpAndSettle();
      final error = tester.takeException();
      expect(
        error,
        isNull,
        reason: 'تجاوز إطار على ${device.name} بمقياس خط ×$scale',
      );
    }
  }
}
