import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';

/// Window size classes, after Material 3's own breakpoints.
///
/// **Measured on the window, not the device**: a tablet in split screen
/// gives the app a phone's width, and must get the phone layout with it.
enum MTWindowClass {
  /// Under 600 points: every phone. The layout every screen was built for.
  compact,

  /// 600 to 839: a small tablet upright, an open foldable, a large tablet
  /// in split screen.
  medium,

  /// 840 and wider: a tablet on its side, a large tablet.
  expanded,
}

abstract final class MTBreakpoint {
  static const double medium = 600;
  static const double expanded = 840;

  /// The widest a column of rows or settings may grow. Past it a row's
  /// title sits far from its trailing button and lines get too long to
  /// scan.
  static const double readable = 720;

  /// The widest the audio player's cover, slider and buttons may spread.
  static const double player = 560;

  /// The widest a tile in a two-up grid may grow. Every phone, down to 320
  /// points, still fits exactly two; a wider window gains columns.
  static const double gridTile = 240;

  /// A panel beside wide content, such as a clip's details beside its
  /// video on a tablet held sideways.
  static const double sidePanel = 400;

  static MTWindowClass classOf(double width) => width >= expanded
      ? MTWindowClass.expanded
      : width >= medium
      ? MTWindowClass.medium
      : MTWindowClass.compact;
}

extension MTWindowClassOf on BuildContext {
  MTWindowClass get windowClass =>
      MTBreakpoint.classOf(MediaQuery.sizeOf(this).width);
}

/// Centres [child] in at most [maxWidth] points.
///
/// On a phone the window is narrower than [maxWidth] and this is a no-op,
/// which is the point: phones keep exactly the layout they had.
class MTReadableWidth extends StatelessWidget {
  const MTReadableWidth({
    super.key,
    required this.child,
    this.maxWidth = MTBreakpoint.readable,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    // As tall as the child, never taller: in the bottom bar's slot an
    // `Align` would otherwise take the whole screen's height.
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// One destination of the shell, drawn as a bottom bar item on a phone and
/// as a rail item from medium width.
class MTNavItem {
  const MTNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// The shell's frame: **a bottom bar on a phone, a side rail from medium
/// width**.
///
/// A bottom bar stretched across a tablet puts three icons a hand apart,
/// and its height comes out of a screen that is short when held sideways.
/// The rail sits on the reading side (the right in Arabic, since `Row`
/// follows the text direction) and gives the height back to the content.
///
/// [bottomAccessories] (the clipboard bar, the mini player) stay at the
/// bottom in both shapes, under the content and not under the rail.
/// [endPane] (the player panel) stands on the far side of the content on a
/// tablet held sideways; the app passes it only when it should show.
class MTAdaptiveScaffold extends StatelessWidget {
  const MTAdaptiveScaffold({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonAnimator,
    this.bottomAccessories = const [],
    this.endPane,
  });

  final List<MTNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonAnimator? floatingActionButtonAnimator;
  final List<Widget> bottomAccessories;
  final Widget? endPane;

  /// Whether the rail replaces the bar. **The shorter side decides too**: a
  /// phone turned sideways inside the video player is wider than 600 but
  /// still a phone, and the shell under the player must not switch shape.
  static bool hasRail(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width >= MTBreakpoint.medium &&
        size.shortestSide >= MTBreakpoint.medium;
  }

  /// Whether there is room for [endPane] beside the content.
  static bool hasEndPane(BuildContext context) =>
      hasRail(context) &&
      MediaQuery.sizeOf(context).width >= MTBreakpoint.expanded;

  @override
  Widget build(BuildContext context) {
    if (!hasRail(context)) {
      return Scaffold(
        body: body,
        floatingActionButton: floatingActionButton,
        floatingActionButtonAnimator: floatingActionButtonAnimator,
        // The accessories sit **above** the bar inside the same slot, so
        // Scaffold counts their height and lifts the add button over them.
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [...bottomAccessories, _bar()],
        ),
      );
    }
    final palette = MTThemeX.of(context).palette;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final pane = hasEndPane(context) ? endPane : null;
    Widget railSide(Widget child) => SafeArea(
      top: false,
      bottom: false,
      right: rtl,
      left: !rtl,
      child: child,
    );
    return Scaffold(
      body: Row(
        children: [
          railSide(_rail()),
          VerticalDivider(width: 1, thickness: 1, color: palette.line),
          Expanded(child: body),
          if (pane != null) ...[
            VerticalDivider(width: 1, thickness: 1, color: palette.line),
            SizedBox(width: MTBreakpoint.sidePanel, child: pane),
          ],
        ],
      ),
      floatingActionButton: floatingActionButton,
      floatingActionButtonAnimator: floatingActionButtonAnimator,
      // The add button belongs to the content: with the panel showing it
      // moves off the panel, to the content's own corner.
      floatingActionButtonLocation: pane == null
          ? null
          : const _BesidePaneFab(MTBreakpoint.sidePanel + 1),
      // Without the bottom bar nothing else keeps the content clear of the
      // system's gesture area, so this slot does it even when empty.
      bottomNavigationBar: SafeArea(
        top: false,
        child: Row(
          children: [
            railSide(const SizedBox(width: MTRail.width + 1)),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: bottomAccessories,
              ),
            ),
            if (pane != null) const SizedBox(width: MTBreakpoint.sidePanel + 1),
          ],
        ),
      ),
    );
  }

  NavigationBar _bar() => NavigationBar(
    selectedIndex: selectedIndex,
    onDestinationSelected: onSelected,
    destinations: [
      for (final item in items)
        NavigationDestination(
          icon: Icon(item.icon),
          selectedIcon: Icon(item.selectedIcon),
          label: item.label,
        ),
    ],
  );

  NavigationRail _rail() => NavigationRail(
    selectedIndex: selectedIndex,
    onDestinationSelected: onSelected,
    labelType: NavigationRailLabelType.all,
    groupAlignment: -1,
    minWidth: MTRail.width,
    destinations: [
      for (final item in items)
        NavigationRailDestination(
          icon: Icon(item.icon),
          selectedIcon: Icon(item.selectedIcon),
          label: Text(item.label),
          padding: const EdgeInsets.symmetric(vertical: MTSpace.xs),
        ),
    ],
  );
}

/// The end corner of the content rather than of the screen: shifted past a
/// pane standing at the end edge.
class _BesidePaneFab extends FloatingActionButtonLocation {
  const _BesidePaneFab(this.shift);

  final double shift;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final base = FloatingActionButtonLocation.endFloat.getOffset(
      scaffoldGeometry,
    );
    final rtl = scaffoldGeometry.textDirection == TextDirection.rtl;
    return base.translate(rtl ? shift : -shift, 0);
  }
}
