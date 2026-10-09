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
/// bottom in both shapes. In the wide shape they are centred in the
/// readable width rather than stretched under the rail.
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
  });

  final List<MTNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonAnimator? floatingActionButtonAnimator;
  final List<Widget> bottomAccessories;

  @override
  Widget build(BuildContext context) {
    if (context.windowClass == MTWindowClass.compact) {
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
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            top: false,
            bottom: false,
            right: Directionality.of(context) == TextDirection.rtl,
            left: Directionality.of(context) == TextDirection.ltr,
            child: _rail(),
          ),
          VerticalDivider(width: 1, thickness: 1, color: palette.line),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: floatingActionButton,
      floatingActionButtonAnimator: floatingActionButtonAnimator,
      // Without the bottom bar nothing else keeps the content clear of the
      // system's gesture area, so this slot does it even when empty.
      bottomNavigationBar: SafeArea(
        top: false,
        child: MTReadableWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: bottomAccessories,
          ),
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
