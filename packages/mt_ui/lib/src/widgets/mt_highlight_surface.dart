import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';

/// أرضية البطاقة: التحديد لون ثابت، والتوهج لون **يتلاشى من نفسه**.
///
/// `TweenAnimationBuilder` يكفي بلا حالة: يبدأ من 1 وينتهي عند 0 مرة
/// واحدة عند أول بناء، فينطفئ التوهج وحده حتى لو نسي المنادي إطفاءه.
/// تتشاركها بطاقتا القائمة والشبكة كي لا يختلف معنى اللون بين عرضين.
class MTHighlightSurface extends StatelessWidget {
  const MTHighlightSurface({
    super.key,
    required this.selected,
    required this.highlighted,
    required this.child,
    this.borderRadius,
  });

  static const glowFade = Duration(milliseconds: 2400);

  final bool selected;
  final bool highlighted;
  final Widget child;
  final BorderRadiusGeometry? borderRadius;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final base = selected ? p.accentSoft : Colors.transparent;
    final shape = borderRadius == null
        ? null
        : RoundedRectangleBorder(borderRadius: borderRadius!);
    if (!highlighted) {
      return Material(color: base, shape: shape, child: child);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: glowFade,
      curve: Curves.easeOutCubic,
      builder: (context, t, inner) => Material(
        color: Color.lerp(base, p.accentSoft, t),
        shape: shape,
        child: inner,
      ),
      child: child,
    );
  }
}
