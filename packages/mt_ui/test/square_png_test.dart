import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// **The notification's square cover (2026-10-10)**: YouTube's 4:3
/// thumbnail carries its 16:9 picture between black bands, and the
/// notification and the lock screen draw a cover at its own shape.
void main() {
  /// A [width] x [height] PNG: red, with black bands of [band] at the top
  /// and the bottom.
  Future<Uint8List> picture(int width, int height, {int band = 0}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final w = width.toDouble();
    final h = height.toDouble();
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = Colors.black);
    canvas.drawRect(
      Rect.fromLTWH(0, band.toDouble(), w, h - band * 2),
      Paint()..color = const Color(0xFFFF0000),
    );
    final image = await recorder.endRecording().toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<(int, int, Color)> decode(Uint8List png) async {
    final codec = await ui.instantiateImageCodec(png);
    final image = (await codec.getNextFrame()).image;
    final pixels = await image.toByteData();
    final corner = Color.fromARGB(
      pixels!.getUint8(3),
      pixels.getUint8(0),
      pixels.getUint8(1),
      pixels.getUint8(2),
    );
    return (image.width, image.height, corner);
  }

  testWidgets('a letterboxed 4:3 thumbnail becomes a square without bands', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final source = await picture(480, 360, band: 45);
      final square = await mtSquarePng(MemoryImage(source), letterboxed: true);
      final (width, height, corner) = await decode(square!);
      expect((width, height), (270, 270));
      expect(corner, const Color(0xFFFF0000), reason: 'no black band left');
    });
  });

  testWidgets('a wide picture keeps its middle square, capped in size', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final square = await mtSquarePng(MemoryImage(await picture(1280, 720)));
      final (width, height, _) = await decode(square!);
      expect((width, height), (512, 512));
    });
  });

  testWidgets('an image that cannot be read gives nothing', (tester) async {
    await tester.runAsync(() async {
      expect(
        await mtSquarePng(MemoryImage(Uint8List.fromList([1, 2, 3]))),
        isNull,
      );
    });
  });
}
