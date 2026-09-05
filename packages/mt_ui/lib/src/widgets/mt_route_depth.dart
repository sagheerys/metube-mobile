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

/// يُظهر [child] فقط حين لا شيء مكدّس فوق الغلاف — **تلاشٍ خالص**.
///
/// ثلاث محاولات وصلت إلى هذا (بلاغات المالك 2026-09-02 ثم 09-04 ثم
/// 09-05):
///
/// 1. انكماش إلى **صفر**: الاختفاء يُقرأ تلاشياً، لكن العودة من الصفر
///    «تكبيرٌ من نقطة» — حركة بوربوينت.
/// 2. انكماش خفيف (0.92) بمنحنيَين مختلفين للدخول والخروج: أهدأ، لكن
///    القفزة تبقى محسوسة ومنحنى الدخول القوي يعطيها «نبضة».
/// 3. **تلاشٍ وحده بمنحنى واحد في الاتجاهين** — لا حجم يتغير ولا فرق
///    بين الظهور والاختفاء إلا اتجاه الشفافية.
///
/// ولم تكفِ الثالثة (بلاغ المالك 2026-09-05) — **لأن الحركة المزعجة لم
/// تكن حركتنا أصلاً**: `Scaffold` يحرّك فتحة الزر العائم بمحرّكه
/// الافتراضي `_ScalingFabMotionAnimator`، وفيه بنصّ مصدر Flutter:
/// «This rotation will turn on the way **in**, but not on the way out»
/// — دورانٌ عند الظهور وحده. وهذا بالضبط وصف المالك: الظهور غريب
/// والاختفاء عادي. الحلّ في الغلاف: `FloatingActionButtonAnimator
/// .noAnimation` مع إبقاء الزر **مركّباً دائماً** في الفتحة، فلا يرى
/// `Scaffold` تبديلاً يحرّكه، ويبقى التلاشي وحده. و[visible] هي ما
/// يخفيه في تبويب الإعدادات بدل تمرير `null`.
class MTHiddenUnderRoutes extends StatelessWidget {
  const MTHiddenUnderRoutes({
    super.key,
    required this.child,
    this.visible = true,
  });

  final Widget child;

  /// شرط إضافي فوق «لا مسار فوق الغلاف» — تمرير `false` يخفيه بنفس
  /// التلاشي بدل نزعه من الشجرة (فيدور محرّك `Scaffold`).
  final bool visible;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: MTRouteDepth.depth,
        builder: (context, depth, _) {
          final shown = depth == 0 && visible;
          return IgnorePointer(
            ignoring: !shown,
            child: AnimatedOpacity(
              opacity: shown ? 1 : 0,
              duration: MTMotion.reveal,
              curve: MTMotion.ease,
              child: child,
            ),
          );
        },
      );
}
