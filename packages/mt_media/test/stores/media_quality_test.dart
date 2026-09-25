import 'package:flutter_test/flutter_test.dart';
import 'package:mt_media/mt_media.dart';

/// **What a file actually is** (2026-09-25). The values are the owner's own
/// clips, probed on his server: 4096×2160 AV1 at 24, 3840×2160 AV1 at 60,
/// a vertical 1080×1920 VP9 reel, an audio-only SoundCloud track.
void main() {
  group('the resolution people say', () {
    test('4K from either 4096×2160 or 3840×2160', () {
      expect(
        const MediaQuality(width: 4096, height: 2160).resolutionLabel,
        '4K',
      );
      expect(
        const MediaQuality(width: 3840, height: 2160).resolutionLabel,
        '4K',
      );
    });

    test('a vertical reel is named by its shorter side: 1080p, not 1920p', () {
      expect(
        const MediaQuality(width: 1080, height: 1920).resolutionLabel,
        '1080p',
      );
      expect(
        const MediaQuality(width: 1440, height: 2560).resolutionLabel,
        '1440p',
      );
    });

    test('an odd size keeps its own number', () {
      expect(
        const MediaQuality(width: 426, height: 240).resolutionLabel,
        '240p',
      );
    });

    test('no dimensions, no label', () {
      expect(const MediaQuality(videoMime: 'video/avc').resolutionLabel, null);
    });
  });

  group('the codec by name', () {
    test('the ones the owner has: AV1, VP9, H.264, AAC, Opus', () {
      expect(const MediaQuality(videoMime: 'video/av01').videoCodec, 'AV1');
      expect(
        const MediaQuality(videoMime: 'video/x-vnd.on2.vp9').videoCodec,
        'VP9',
      );
      expect(const MediaQuality(videoMime: 'video/avc').videoCodec, 'H.264');
      expect(
        const MediaQuality(audioMime: 'audio/mp4a-latm').audioCodec,
        'AAC',
      );
      expect(const MediaQuality(audioMime: 'audio/opus').audioCodec, 'Opus');
    });

    test('an unknown type still says something, not nothing', () {
      expect(
        const MediaQuality(videoMime: 'video/x-something').videoCodec,
        'X-SOMETHING',
      );
    });
  });

  group('from the platform map', () {
    test('a full answer', () {
      final q = MediaQuality.fromMap({
        'width': 3840,
        'height': 2160,
        'videoMime': 'video/av01',
        'frameRate': 60,
        'audioMime': 'audio/opus',
        'sampleRate': 48000,
        'channels': 2,
      });

      expect(q.resolutionLabel, '4K');
      expect(q.videoCodec, 'AV1');
      expect(q.frameRate, 60);
      expect(q.audioCodec, 'Opus');
      expect(q.hasVideo && q.hasAudio, isTrue);
    });

    test('an audio-only file has no video, and says so', () {
      final q = MediaQuality.fromMap({
        'audioMime': 'audio/mp4a-latm',
        'sampleRate': 44100,
        'channels': 2,
      });

      expect(q.hasVideo, isFalse);
      expect(q.hasAudio, isTrue);
    });

    test('zeros, blanks and wrong types are dropped, not shown', () {
      final q = MediaQuality.fromMap({
        'width': 0,
        'height': 'tall',
        'videoMime': '  ',
        'frameRate': -1,
        'error': 'IOException',
      });

      expect(q.isEmpty, isTrue);
    });
  });
}
