import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

/// **How many routes are stacked above the shell** (field report
/// 2026-09-02).
///
/// The floating add button lives in the shell's `Scaffold`, so it stayed
/// drawn over **every** bottom sheet and dialog: it covered the "about
/// this clip" link and crowded each sheet's own actions. Checking
/// `ModalRoute.of(context).isCurrent` is not enough, because it does not
/// trigger a rebuild.
///
/// This observer is registered once in the router, so anyone who needs it
/// knows how many routes are open above the root, and hides itself at the
/// first one.
class MTRouteDepth extends NavigatorObserver {
  MTRouteDepth._();

  /// A single instance shared by the router and the shell.
  static final MTRouteDepth instance = MTRouteDepth._();

  /// Routes stacked above the root. 0 means nothing covers the shell.
  static final ValueNotifier<int> depth = ValueNotifier<int>(0);

  /// Sheets and dialogs do not count as a "visible" route in some
  /// frameworks. Here everything pushed onto the navigator counts, which is
  /// exactly what is wanted.
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
    // A replacement does not change the depth.
  }
}

/// Shows [child] only while nothing is stacked above the shell, as a
/// **pure fade**.
///
/// Three attempts led here (field reports 2026-09-02, then 09-04, then
/// 09-05):
///
/// 1. 1. Shrinking to **zero**: the disappearance reads as a fade, but
/// coming back from zero is "growing out of a point", a slide-deck move.
/// 2. 2. A light shrink (0.92) with different curves in and out: calmer,
///    but
/// the jump is still felt and the strong entry curve gives it a pulse.
/// 3. 3. **A fade alone, one curve in both directions**: no size change,
///    and
/// no difference between appearing and disappearing except the direction
/// of the opacity.
///
/// And the third was still not enough (field report 2026-09-05), **because
/// the motion that annoyed was never ours**: `Scaffold` animates the
/// floating action button slot with its own default
/// `_ScalingFabMotionAnimator`, which says verbatim in the Flutter source:
/// "This rotation will turn on the way **in**, but not on the way out".
/// A rotation on appearance only. That matches the report exactly:
/// appearing looked odd, disappearing looked normal. The fix lives in the
/// shell: `FloatingActionButtonAnimator.noAnimation` while keeping the
/// button **always mounted** in the slot, so `Scaffold` never sees a swap
/// to animate and only the fade remains. [visible] is what hides it on the
/// settings tab, instead of passing `null`.
class MTHiddenUnderRoutes extends StatelessWidget {
  const MTHiddenUnderRoutes({
    super.key,
    required this.child,
    this.visible = true,
  });

  final Widget child;

  /// An extra condition on top of "no route above the shell". Passing
  /// `false` hides it with the same fade instead of removing it from the
  /// tree, which would wake the `Scaffold` animator.
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
