import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// **حركة «وهج»** (طلب المالك 2026-09-02) — كل الأزمنة والمنحنيات من
/// [MTMotion] في `tokens.dart`، صفر قيمة مثبتة هنا.
///
/// الهوية تحريرية دافئة لا واجهة ألعاب، فالقاعدة: **الحركة تشرح ولا
/// تستعرض**. ثلاث حركات فقط، ولكلٍّ سبب:
///
/// 1. [MTFadeSlideIn] — ظهور متتابع لعناصر القائمة: يقول «هذه قائمة
///    تُبنى» بدل ظهور كتلة صمّاء، ويخفي الفارق بين إطار المكتبة الأول
///    وما يليه.
/// 2. [MTPageTransitions] — انتقال الشاشات: انزلاق خفيف يحترم اتجاه
///    اللغة، فيُفهم «دخلتُ» و«رجعتُ» بلا قراءة.
/// 3. [MTAnimatedSwap] — تبدّل محتوى في مكانه (حالة فارغة ⇄ قائمة،
///    شارة ⇄ شارة): تلاشٍ متقاطع قصير بدل قفزة.
///
/// **حدّ أقصى مقصود:** لا حركة تتجاوز [MTMotion.medium]، ولا ارتداد
/// (`elasticOut`/`bounceOut`) في أي مكان.

/// ظهور عنصر: تلاشٍ + انزلاق قصير لأعلى. [index] يُنتج تأخيراً متتابعاً
/// محدوداً بـ [MTMotion.staggerLimit] كي لا ينتظر العنصر الخمسون دهراً.
class MTFadeSlideIn extends StatefulWidget {
  const MTFadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 14,
  });

  final Widget child;
  final int index;

  /// مسافة الانزلاق بالنقاط — صغيرة عمداً: الحركة تُلمَح لا تُشاهَد.
  final double offset;

  @override
  State<MTFadeSlideIn> createState() => _MTFadeSlideInState();
}

class _MTFadeSlideInState extends State<MTFadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: MTMotion.medium,
  );

  @override
  void initState() {
    super.initState();
    final delay = MTMotion.stagger *
        widget.index.clamp(0, MTMotion.staggerLimit);
    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(delay, () {
        // العنصر قد يخرج من الشاشة قبل دوره (تمرير سريع).
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // احترام إعداد النظام «تقليل الحركة» — شرط وصول لا تحسين.
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    final curved =
        CurvedAnimation(parent: _controller, curve: MTMotion.entrance);
    return FadeTransition(
      opacity: curved,
      child: AnimatedBuilder(
        animation: curved,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, widget.offset * (1 - curved.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// تبدّل محتوى في مكانه بتلاشٍ متقاطع — لا انزلاق: العنصر لم ينتقل،
/// بل تغيّر.
class MTAnimatedSwap extends StatelessWidget {
  const MTAnimatedSwap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: MTMotion.tap,
        switchInCurve: MTMotion.entrance,
        switchOutCurve: MTMotion.exit,
        child: child,
      );
}

/// انتقال الشاشات: انزلاق **باتجاه اللغة** + تلاشٍ.
///
/// الافتراضي في أندرويد صعودٌ رأسي لا يقول شيئاً عن العلاقة بين
/// الشاشتين؛ الانزلاق الأفقي يقول «دخلتُ أعمق» و«رجعتُ» — وينعكس في
/// العربية تلقائياً لأنه يقرأ [Directionality].
class MTSlidePageTransition extends PageTransitionsBuilder {
  const MTSlidePageTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final sign = rtl ? -1.0 : 1.0;
    final enter = Tween<Offset>(
      begin: Offset(0.22 * sign, 0),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: animation, curve: MTMotion.entrance));
    // الشاشة المغادرة تنزاح قليلاً فقط: تبقى حاضرة ذهنياً تحت الجديدة.
    final leave = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(-0.08 * sign, 0),
    ).animate(
        CurvedAnimation(parent: secondaryAnimation, curve: MTMotion.exit));

    return SlideTransition(
      position: leave,
      child: SlideTransition(
        position: enter,
        child: FadeTransition(opacity: animation, child: child),
      ),
    );
  }
}

/// يُركَّب على `ThemeData.pageTransitionsTheme` في كلا التطبيقين.
const mtPageTransitionsTheme = PageTransitionsTheme(builders: {
  TargetPlatform.android: MTSlidePageTransition(),
  TargetPlatform.iOS: MTSlidePageTransition(),
});
