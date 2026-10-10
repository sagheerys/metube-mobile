import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/playback_source.dart';

/// Tells an AV1 clip from the first bytes of its file, before it is opened.
///
/// **A phone without an AV1 decoder in hardware draws AV1 wrong on the
/// texture path.** Measured on a Snapdragon 8 Gen 1 flagship: Android hands
/// AV1 to its software decoder, and the frames it leaves in Flutter's
/// `ImageReader` come out covered in green dashes and stray lines, from
/// mild on a lit scene to unreadable on a dark one. The same file decodes
/// cleanly elsewhere, H.264 and VP9 on the hardware decoder are clean, and
/// the same AV1 clip drawn into a platform view is clean. No error is
/// raised, so nothing after opening can catch it: the codec has to be
/// known before the surface is chosen.
///
/// Anything that goes wrong here (no file, no network, a slow server, a
/// format not recognised) answers "not AV1", which is the path every clip
/// took before this existed.
abstract final class MTVideoCodec {
  /// Enough for a WebM's track list and for an MP4 whose index comes first,
  /// which is how yt-dlp writes them.
  static const headBytes = 64 * 1024;

  /// A clip waits at most this long for the answer, then opens as before.
  static const patience = Duration(seconds: 2);

  static final _known = <String, bool>{};

  /// Reads the start of the file; replaced in tests.
  @visibleForTesting
  static Future<List<int>?> Function(PlaybackSource source) readHead =
      _readHead;

  /// Forgets what was learned, for tests.
  @visibleForTesting
  static void reset() => _known.clear();

  static Future<bool> isAv1(PlaybackSource source) async {
    final key = source.uri.toString();
    if (_known[key] case final known?) return known;
    List<int>? head;
    try {
      head = await readHead(source).timeout(patience);
    } on Object {
      head = null;
    }
    // A failed read is not remembered: the next attempt may well succeed.
    if (head == null) return false;
    return _known[key] = av1InHead(head);
  }

  /// WebM names its codec `V_AV1`. An MP4 holds an `av01` sample entry
  /// with its `av1C` configuration inside, both required so that four
  /// stray bytes of picture data cannot pass for a codec.
  @visibleForTesting
  static bool av1InHead(List<int> head) =>
      _contains(head, 'V_AV1'.codeUnits) ||
      (_contains(head, 'av01'.codeUnits) && _contains(head, 'av1C'.codeUnits));

  static bool _contains(List<int> data, List<int> marker) {
    final last = data.length - marker.length;
    outer:
    for (var i = 0; i <= last; i++) {
      for (var j = 0; j < marker.length; j++) {
        if (data[i + j] != marker[j]) continue outer;
      }
      return true;
    }
    return false;
  }

  static Future<List<int>?> _readHead(PlaybackSource source) async {
    if (source.isLocal) {
      final file = await File(source.uri.toFilePath()).open();
      try {
        return await file.read(headBytes);
      } finally {
        await file.close();
      }
    }
    final client = HttpClient();
    try {
      final request = await client.getUrl(source.uri);
      source.headers.forEach(request.headers.set);
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-${headBytes - 1}');
      final response = await request.close();
      if (response.statusCode != HttpStatus.partialContent &&
          response.statusCode != HttpStatus.ok) {
        return null;
      }
      // A server that ignores the range sends the whole file: stop reading
      // once the head is in.
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        if (bytes.length >= headBytes) break;
      }
      return bytes.length > headBytes ? bytes.sublist(0, headBytes) : bytes;
    } finally {
      client.close(force: true);
    }
  }
}
