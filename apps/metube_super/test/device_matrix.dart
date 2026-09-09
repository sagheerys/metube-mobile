import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// **مصفوفة الأجهزة** — بديل امتلاك عشرين هاتفاً.
///
/// المالك يملك جهازين: المحاكي (411×914 نقطة) والجلاكسي S22 ألترا
/// (384×823). كل ما عداهما لا يُفحص بالعين أبداً، والانكسار الشائع في
/// أندرويد ليس في المنطق بل في **التخطيط**: شاشة أقصر، أو خط النظام
/// مكبَّراً لأسباب بصرية، يدفعان محتوىً كان يتّسع خارج الإطار.
///
/// هذه المصفوفة تعرض الودجت على المقاسات الحرجة × مقاييس الخط، وتلتقط
/// `RenderFlex overflowed` من محرّك Flutter نفسه — وهو الخطأ الذي يظهر
/// على جهاز المستخدم شريطاً أصفر وأسود ولا يظهر على جهاز المطوّر.
class MTDevice {
  const MTDevice(this.name, this.size);

  final String name;
  final Size size;

  /// المقاسات بالنقاط المنطقية (dp) لا بالبكسل.
  static const List<MTDevice> all = [
    // أصغر شاشة أندرويد واقعية لا تزال تتلقى تحديثات.
    MTDevice('صغير 320×534', Size(320, 534)),
    MTDevice('اقتصادي 360×640', Size(360, 640)),
    // جهاز المالك الفعلي.
    MTDevice('جلاكسي S22 ألترا 384×823', Size(384, 823)),
    MTDevice('محاكي المشروع 411×914', Size(411, 914)),
    MTDevice('لوحي 800×1280', Size(800, 1280)),
  ];
}

/// مقاييس الخط: العادي، الشائع بين كبار السن، وسقف أندرويد للإتاحة.
const List<double> mtTextScales = [1.0, 1.3, 2.0];

/// يبني [child] على كل مقاس × كل مقياس خط ويفشل عند أول تجاوز إطار.
///
/// [maxScaleFor] تسمح باستثناء موثَّق: بعض المقاسات الصغيرة جداً مع
/// ×2.0 لا تتسع لأي تصميم، والقرار حينها «يمرَّر» لا «يُخفى».
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
