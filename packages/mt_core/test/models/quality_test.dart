import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

void main() {
  group('Quality.applyRule: the numeric qualities are YouTube only', () {
    const youtube = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
    const tiktok = 'https://www.tiktok.com/@user/video/7301234567890123456';

    test('1080 on YouTube survives', () {
      expect(Quality.q1080.applyRule(youtube), Quality.q1080);
    });

    test('720 and 480 on TikTok are forced to best', () {
      expect(Quality.q720.applyRule(tiktok), Quality.best);
      expect(Quality.q480.applyRule(tiktok), Quality.best);
    });

    test('audio works everywhere', () {
      expect(Quality.audio.applyRule(tiktok), Quality.audio);
      expect(Quality.audio.applyRule(youtube), Quality.audio);
    });

    test('best always survives', () {
      expect(Quality.best.applyRule(tiktok), Quality.best);
    });

    test('the short youtu.be form is treated as YouTube', () {
      expect(
        Quality.q1080.applyRule('https://youtu.be/dQw4w9WgXcQ'),
        Quality.q1080,
      );
    });
  });

  group('Quality.fromWire', () {
    test('the valid values', () {
      expect(Quality.fromWire('1080'), Quality.q1080);
      expect(Quality.fromWire('audio'), Quality.audio);
      expect(Quality.fromWire('BEST'), Quality.best);
    });

    test('anything unknown, or null, becomes best', () {
      expect(Quality.fromWire('4k'), Quality.best);
      expect(Quality.fromWire(null), Quality.best);
    });
  });

  test('the wire list matches the constants', () {
    expect(Quality.values.map((q) => q.wire), MTConstants.qualityWireValues);
  });
}
