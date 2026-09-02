import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// **حركة «وهج»** — كل الأزمنة والمسافات من [MTMotion] في `tokens.dart`،
/// صفر قيمة مثبتة هنا.
///
/// **المراجعة الثانية (بلاغ المالك 2026-09-02: «الحركات غير متزنة،
/// خففها واجعلها أكثر سلاسة»).** المحاولة الأولى كانت تحرّك **كل بطاقة
/// عند إنشائها**، و`SliverList.builder` ينشئ البطاقات وأنت تمرّر — فكل
/// صف يدخل الشاشة كان يبدأ تلاشياً وانزلاقاً من جديد. النتيجة قائمة
/// «تنطّ» طوال التمرير، وهي بالضبط ما وصفه المالك.
///
/// العلاج مبدئي لا تجميلي: **الشاشة تدخل مرة واحدة، لا عناصرها.**
/// [MTRevealOnce] يحرّك الكتلة كلها عند أول ظهور ثم يزيح نفسه من
/// الشجرة، فلا يبقى أي `AnimationController` ولا أي عمل أثناء التمرير.
///
/// الحركات الثلاث الباقية:
/// 1. [MTRevealOnce] — دخول محتوى الشاشة مرة واحدة.
/// 2. [MTSlidePageTransition] — انتقال الشاشات باتجاه اللغة.
/// 3. [MTAnimatedSwap] — تبدّل محتوى في مكانه.

/// ظهور **لمرة واحدة** لكتلة محتوى: تلاشٍ + إزاحة قصيرة جداً.
///
/// بعد انتهاء الحركة يعيد [child] عارياً — لا `Transform` ولا
/// `FadeTransition` باقيان في الشجرة، فلا كلفة على التمرير بعدها.
class MTRevealOnce extends StatefulWidget {
  const MTRevealOnce({super.key, required this.child, this.delay});

  final Widget child;

  /// تأخير اختياري لتتابع خفيف بين كتلتين (لا بين عشرات العناصر).
  final Duration? delay;

  @override
  State<MTRevealOnce> createState() => _MTRevealOnceState();
}

class _MTRevealOnceState extends State<MTRevealOnce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: MTMotion.reveal,
  );

  /// **يُنشأ مرة واحدة لا كل إطار (إصلاح م-2/ب):** `CurvedAnimation` في
  /// `build` كان يُخلق ويُهمل ٦٠ مرة بالثانية بلا تصريف.
  late final CurvedAnimation _curved =
      CurvedAnimation(parent: _controller, curve: MTMotion.entrance);

  @override
  void initState() {
    super.initState();
    final delay = widget.delay;
    if (delay == null || delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // احترام «تقليل الحركة» في إعدادات النظام — شرط وصول لا تحسين.
    if (MediaQuery.disableAnimationsOf(context)) _controller.value = 1;
  }

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// **شكل الشجرة ثابت من أول إطار لآخره (إصلاح م-2/أ).** كان الودجت
  /// يستبدل الغلاف كله بـ`widget.child` عند انتهاء الحركة، فيتغير عمق
  /// العناصر ويُعاد بناء الشجرة تحته: تمرير أو كتابة بدآ خلال أول
  /// 220ms كانا يُفقدان. الآن ينتهي المتحكم عند 1 فيتوقف إعادة البناء
  /// وحده بلا لمس الشكل.
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _curved,
        builder: (context, child) => Opacity(
          opacity: _curved.value,
          child: Transform.translate(
            offset: Offset(0, MTMotion.slideNudge * (1 - _curved.value)),
            child: child,
          ),
        ),
        child: widget.child,
      );
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

/// انتقال الشاشات: تلاشٍ + إزاحة **قصيرة** باتجاه اللغة.
///
/// الافتراضي في أندرويد صعودٌ رأسي لا يقول شيئاً عن علاقة الشاشتين؛
/// الإزاحة الأفقية تقول «دخلتُ أعمق» و«رجعتُ». والمسافة صغيرة عمداً
/// (`pageSlide`): الانزلاق الطويل هو ما يُقرأ «قفزة».
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
      begin: Offset(MTMotion.pageSlide * sign, 0),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: animation, curve: MTMotion.entrance));

    return SlideTransition(
      position: enter,
      // التلاشي هو الحامل الأساسي للانتقال، والإزاحة تلميح اتجاه فقط.
      child: FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: MTMotion.entrance),
        child: child,
      ),
    );
  }
}

/// يُركَّب على `ThemeData.pageTransitionsTheme` في كلا التطبيقين.
const mtPageTransitionsTheme = PageTransitionsTheme(builders: {
  TargetPlatform.android: MTSlidePageTransition(),
  TargetPlatform.iOS: MTSlidePageTransition(),
});
