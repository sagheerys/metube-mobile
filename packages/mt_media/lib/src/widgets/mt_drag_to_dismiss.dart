import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

/// **سحب عمودي يغلق الشاشة**: المحتوى يتبع الإصبع لأسفل (لا لأعلى)،
/// وعند الرفع إمّا يُغلق — إن تجاوزت المسافة [MTMotion.dismissDragDistance]
/// أو السرعة [MTMotion.dismissFlingVelocity] — أو يعود إلى مكانه بهدوء.
///
/// **لا يتنافس مع شيء**: شريط التقدّم يسحب أفقياً والأزرار تنقر؛
/// `onVerticalDragUpdate` وحده هنا. وحين يطلب النظام تقليل الحركة
/// يعمل الإغلاق بلا تتبّع بصري.
class MTDragToDismiss extends StatefulWidget {
  const MTDragToDismiss({super.key, required this.child});

  final Widget child;

  @override
  State<MTDragToDismiss> createState() => _MTDragToDismissState();
}

class _MTDragToDismissState extends State<MTDragToDismiss>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: MTMotion.tap,
  )..addListener(() => setState(() => _offset = _settle.value * _from));

  double _offset = 0;
  double _from = 0;

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _onUpdate(DragUpdateDetails d) {
    if (_settle.isAnimating) _settle.stop();
    setState(() => _offset = (_offset + d.delta.dy).clamp(0, double.infinity));
  }

  void _onEnd(DragEndDetails d) {
    final velocity = d.velocity.pixelsPerSecond.dy;
    if (_offset > MTMotion.dismissDragDistance ||
        velocity > MTMotion.dismissFlingVelocity) {
      Navigator.of(context).maybePop();
      return;
    }
    // عودة هادئة إلى المكان — بلا ارتداد.
    _from = _offset;
    _settle
      ..value = 1
      ..animateTo(0, curve: MTMotion.entrance);
  }

  @override
  Widget build(BuildContext context) {
    final follow = !MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: _onUpdate,
      onVerticalDragEnd: _onEnd,
      child: Transform.translate(
        offset: Offset(0, follow ? _offset : 0),
        child: widget.child,
      ),
    );
  }
}
