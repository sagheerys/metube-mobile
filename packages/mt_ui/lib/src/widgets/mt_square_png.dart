import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// The middle square of an image, as a PNG of at most [side] pixels.
///
/// For the media notification and the lock screen, which draw a cover at
/// its own shape: a YouTube thumbnail there is a wide strip where a music
/// app shows a square. [letterboxed] is for a 4:3 picture that carries a
/// 16:9 one between black bands (YouTube's `hqdefault`): the square is
/// taken inside the picture, so the bands stay out. Null when the image
/// cannot be loaded or decoded.
Future<Uint8List?> mtSquarePng(
  ImageProvider provider, {
  bool letterboxed = false,
  int side = 512,
  Duration patience = const Duration(seconds: 20),
}) async {
  final image = await _load(provider).timeout(patience, onTimeout: () => null);
  if (image == null) return null;
  try {
    final width = image.width.toDouble();
    final height = image.height.toDouble();
    final square = math.min(width, letterboxed ? height * 3 / 4 : height);
    if (square < 1) return null;
    final out = math.min(side.toDouble(), square).round();
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      image,
      Rect.fromCenter(
        center: Offset(width / 2, height / 2),
        width: square,
        height: square,
      ),
      Rect.fromLTWH(0, 0, out.toDouble(), out.toDouble()),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final picture = recorder.endRecording();
    final cropped = await picture.toImage(out, out);
    picture.dispose();
    try {
      final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      cropped.dispose();
    }
  } finally {
    image.dispose();
  }
}

Future<ui.Image?> _load(ImageProvider provider) {
  final done = Completer<ui.Image?>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      if (!done.isCompleted) done.complete(info.image.clone());
      info.dispose();
      stream.removeListener(listener);
    },
    onError: (_, _) {
      if (!done.isCompleted) done.complete(null);
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  return done.future;
}
