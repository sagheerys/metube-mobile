import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

void main() {
  group('Quality.applyRule — الرقمية ليوتيوب فقط', () {
    const youtube = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
    const tiktok = 'https://www.tiktok.com/@user/video/7301234567890123456';

    test('1080 على YouTube تبقى', () {
      expect(Quality.q1080.applyRule(youtube), Quality.q1080);
    });

    test('720/480 على TikTok تُجبر على best', () {
      expect(Quality.q720.applyRule(tiktok), Quality.best);
      expect(Quality.q480.applyRule(tiktok), Quality.best);
    });

    test('audio للجميع', () {
      expect(Quality.audio.applyRule(tiktok), Quality.audio);
      expect(Quality.audio.applyRule(youtube), Quality.audio);
    });

    test('best تبقى دائماً', () {
      expect(Quality.best.applyRule(tiktok), Quality.best);
    });

    test('youtu.be القصير يُعامل كيوتيوب', () {
      expect(Quality.q1080.applyRule('https://youtu.be/dQw4w9WgXcQ'),
          Quality.q1080);
    });
  });

  group('Quality.fromWire', () {
    test('القيم الصالحة', () {
      expect(Quality.fromWire('1080'), Quality.q1080);
      expect(Quality.fromWire('audio'), Quality.audio);
      expect(Quality.fromWire('BEST'), Quality.best);
    });

    test('غير المعروف/null ⇒ best', () {
      expect(Quality.fromWire('4k'), Quality.best);
      expect(Quality.fromWire(null), Quality.best);
    });
  });

  test('قائمة الأسلاك مطابقة للثوابت', () {
    expect(Quality.values.map((q) => q.wire), MTConstants.qualityWireValues);
  });
}
