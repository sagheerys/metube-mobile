import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

void main() {
  group('AppVersion.tryParse', () {
    test('يقبل الصيغ التي يصدرها المشروع فعلاً', () {
      expect(AppVersion.tryParse('2.0.0').toString(), '2.0.0');
      expect(AppVersion.tryParse('v2.1.3').toString(), '2.1.3');
      // `pubspec` يكتب `2.0.0+1` و`package_info` يعيدها كذلك أحياناً.
      expect(AppVersion.tryParse('2.0.0+7').toString(), '2.0.0');
      expect(AppVersion.tryParse('  v2.1.0  ').toString(), '2.1.0');
      expect(AppVersion.tryParse('2.1').toString(), '2.1.0');
      expect(AppVersion.tryParse('3').toString(), '3.0.0');
    });

    test('يرفض ما لا يُقارَن بدل تخمينه', () {
      for (final bad in [
        null,
        '',
        '  ',
        'latest',
        '2.x.0',
        '2.0.0.1',
        '-1.0.0',
      ]) {
        expect(AppVersion.tryParse(bad), isNull, reason: 'رفض «$bad»');
      }
    });

    test('يقرأ الإصدار التجريبي ويحتفظ بلاحقته', () {
      final v = AppVersion.tryParse('2.1.0-beta.1')!;
      expect(v.preRelease, 'beta.1');
      // `+` قبل `-` في القطع: `2.1.0-beta+7` لاحقتها `beta` لا `beta+7`.
      expect(AppVersion.tryParse('2.1.0-beta+7')!.preRelease, 'beta');
    });
  });

  group('المقارنة', () {
    test('**الحارس**: 2.10.0 أحدث من 2.9.0', () {
      // المقارنة النصية تعطي العكس (`'1' < '9'`) فيتجمّد المستخدم على
      // 2.9.0 إلى الأبد — هذا سبب وجود الصنف كله.
      expect('2.10.0'.compareTo('2.9.0'), lessThan(0));
      expect(
        AppVersion.tryParse('2.10.0')! > AppVersion.tryParse('2.9.0')!,
        isTrue,
      );
    });

    test('الترتيب على المستويات الثلاثة', () {
      expect(
        AppVersion.tryParse('3.0.0')! > AppVersion.tryParse('2.99.99')!,
        isTrue,
      );
      expect(
        AppVersion.tryParse('2.1.0')! > AppVersion.tryParse('2.0.99')!,
        isTrue,
      );
      expect(
        AppVersion.tryParse('2.0.1')! > AppVersion.tryParse('2.0.0')!,
        isTrue,
      );
      expect(
        AppVersion.tryParse('2.0.0')! == AppVersion.tryParse('v2.0.0+9')!,
        isTrue,
      );
    });

    test('التجريبي أدنى من المستقر نفسه', () {
      final beta = AppVersion.tryParse('2.1.0-beta.1')!;
      final stable = AppVersion.tryParse('2.1.0')!;
      expect(beta < stable, isTrue);
      // ومن يملك التجريبي يرى المستقر تحديثاً.
      expect(stable > beta, isTrue);
      expect(
        AppVersion.tryParse('2.1.0-beta.2')! >
            AppVersion.tryParse('2.1.0-beta.1')!,
        isTrue,
      );
    });
  });
}
