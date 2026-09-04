import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

/// **عمق المسارات فوق الغلاف** (بلاغ المالك 2026-09-02).
///
/// زر الإضافة العائم يعيش في `Scaffold` الغلاف، فيبقى مرسوماً فوق **كل**
/// ورقة سفلية وحوار — يحجب رابط «حول المقطع» ويزاحم أفعال الورقة. ولا
/// يكفي فحص `ModalRoute.of(context).isCurrent` لأنه لا يُطلق إعادة بناء.
///
/// هذا المراقب يُسجَّل في الراوتر مرة، فيَعرف كل من يريد كم مساراً فُتح
/// فوق الجذر — فيخفي نفسه عند أول واحد.
class MTRouteDepth extends NavigatorObserver {
  MTRouteDepth._();

  /// نسخة واحدة يشترك فيها الراوتر والغلاف.
  static final MTRouteDepth instance = MTRouteDepth._();

  /// عدد المسارات المكدّسة فوق الجذر. 0 = لا شيء يغطي الغلاف.
  static final ValueNotifier<int> depth = ValueNotifier<int>(0);

  /// الأوراق والحوارات لا تُحسب مساراً «مرئياً» في بعض الأطر — هنا كل
  /// ما يُدفع على الملّاح يُحسب، وهو المطلوب بالضبط.
  void _set(int value) => depth.value = value < 0 ? 0 : value;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) _set(depth.value + 1);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _set(depth.value - 1);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _set(depth.value - 1);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    // استبدال لا يغيّر العمق.
  }
}

/// يُظهر [child] فقط حين لا شيء مكدّس فوق الغلاف، بتلاشٍ قصير بدل
/// اختفاء مفاجئ.
///
/// **الظهور مرآة الاختفاء** (بلاغ المالك 2026-09-04: «حركة ظهور زر
/// إضافة رابط أريدها مثل حركة اختفائه لا مثل الباوربوينت»). كان الزر
/// ينكمش إلى **صفر** فيُقرأ اختفاؤه تلاشياً سريعاً، لكن عودته من الصفر
/// تُقرأ «تكبيراً من نقطة». الآن الانكماش خفيف ([_hiddenScale]) فيبقى
/// الاتجاهان تلاشياً واحداً بنفس المدة.
class MTHiddenUnderRoutes extends StatelessWidget {
  const MTHiddenUnderRoutes({super.key, required this.child});

  final Widget child;

  static const double _hiddenScale = 0.92;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: MTRouteDepth.depth,
        builder: (context, depth, _) {
          final visible = depth == 0;
          final curve = visible ? MTMotion.entrance : MTMotion.exit;
          return IgnorePointer(
            ignoring: !visible,
            child: AnimatedScale(
              scale: visible ? 1 : _hiddenScale,
              duration: MTMotion.tap,
              curve: curve,
              child: AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: MTMotion.tap,
                curve: curve,
                child: child,
              ),
            ),
          );
        },
      );
}
