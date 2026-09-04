import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// **لمسات «وهج» الخفيفة** (طلب المالك 2026-09-04: «حركات لبعض
/// الأيقونات، لمسات خفيفة جميلة ومتناسقة ومناسبة للتطبيقين»).
///
/// ثلاثة مكوّنات صغيرة تُستعمل في التطبيقين معاً، كلها بأزمنة
/// [MTMotion] وبلا ارتداد (سجل §4: `elasticOut`/`bounceOut` ممنوعة)،
/// وكلها تُطفئ نفسها مع «تقليل الحركة» في إعدادات النظام.

/// المدة الفعلية: صفر حين يطلب النظام تقليل الحركة.
Duration mtMotionDuration(BuildContext context, Duration duration) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;

/// **انكماش خفيف عند الضغط** — يقول «هذا زر» قبل أن يفعل شيئاً.
///
/// لا يستبدل `InkWell` بل يغلّفه: الموجة تبقى، والانكماش يُضاف.
/// يعمل بمستوى المؤشر لا `GestureDetector` كي لا يتنافس على النقرة.
class MTPressable extends StatefulWidget {
  const MTPressable({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = MTMotion.pressScale,
  });

  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<MTPressable> createState() => _MTPressableState();
}

class _MTPressableState extends State<MTPressable> {
  bool _down = false;

  void _set(bool down) {
    if (_down == down || !widget.enabled) return;
    setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.deferToChild,
    onPointerDown: (_) => _set(true),
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: AnimatedScale(
      scale: _down ? widget.scale : 1,
      duration: mtMotionDuration(context, MTMotion.tap),
      // الخروج حاسم عند الضغط، والعودة هادئة عند الرفع.
      curve: _down ? MTMotion.exit : MTMotion.entrance,
      child: widget.child,
    ),
  );
}

/// **تبديل أيقونة في مكانها**: القديمة تتلاشى منكمشةً والجديدة تتسع من
/// [MTMotion.iconSwapScale] إلى حجمها — لا قفزة بين ▶ و⏸، ولا بين ♡ و♥.
///
/// المفتاح هو الأيقونة نفسها، فلا حركة ما لم تتغير.
class MTIconSwap extends StatelessWidget {
  const MTIconSwap({
    super.key,
    required this.icon,
    this.size,
    this.color,
    this.semanticLabel,
    this.shadows,
  });

  final IconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;
  final List<Shadow>? shadows;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: mtMotionDuration(context, MTMotion.tap),
    switchInCurve: MTMotion.entrance,
    switchOutCurve: MTMotion.exit,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(
          begin: MTMotion.iconSwapScale,
          end: 1,
        ).animate(animation),
        child: child,
      ),
    ),
    child: Icon(
      icon,
      key: ValueKey(icon.codePoint),
      size: size,
      color: color,
      semanticLabel: semanticLabel,
      shadows: shadows,
    ),
  );
}

/// **انتقال «ورقة صاعدة»**: الشاشة تصعد من أسفل كاملةً بينما تخفت التي
/// تحتها قليلاً — للشاشات التي «تتوسّع» من عنصر سفلي (المشغل المصغر ⇒
/// شاشة الصوت). الرجوع يعكسه فيبدو أنها عادت إلى مكانها.
///
/// يُستعمل مع `CustomTransitionPage` في جدول المسارات — لا يستبدل
/// انتقال الشاشات الأفقي المعتمد لبقية المسارات.
Widget mtSheetPageTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  if (MediaQuery.disableAnimationsOf(context)) return child;
  final rise = CurvedAnimation(
    parent: animation,
    curve: MTMotion.entrance,
    reverseCurve: MTMotion.exit,
  );
  return SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(rise),
    child: child,
  );
}
