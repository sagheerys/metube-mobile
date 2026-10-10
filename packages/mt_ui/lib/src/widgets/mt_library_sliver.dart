import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import 'mt_adaptive.dart';
import 'mt_media_row.dart';

/// The four ways the library can lay out its items, as the user picks them.
enum MTLibraryLayout { list, compact, grid, cards }

/// Builds one library item. [columns] is non-null only for a row in a
/// tablet's table, which then draws an [MTMediaRow].
typedef MTLibraryItemBuilder = Widget Function(
  BuildContext context,
  int index,
  MTMediaColumns? columns,
);

/// The library's items as a sliver, in the user's layout.
///
/// **A phone keeps one column**, exactly as before. **A tablet gives every
/// layout its own use of the width** instead of a phone's column stretched
/// sideways: large cards gain columns, compact rows sit two or three
/// across, and the list becomes a table whose columns show what a phone
/// hides in the item's sheet. The counts follow the width the library
/// actually has, so they change on their own when the player panel opens
/// or folds.
///
/// Every layout is lazy: only what is on screen is built, which is what
/// lets a library of hundreds scroll without freezing.
class MTLibrarySliver extends StatelessWidget {
  const MTLibrarySliver({
    super.key,
    required this.layout,
    required this.itemCount,
    required this.itemBuilder,
    this.showLocation = false,
  });

  final MTLibraryLayout layout;
  final int itemCount;
  final MTLibraryItemBuilder itemBuilder;

  /// Whether the table has a "where is it" column. Only a library that
  /// mixes the server's files with the device's has something to say there.
  final bool showLocation;

  @override
  Widget build(BuildContext context) {
    final tablet = MTAdaptiveScaffold.hasRail(context);
    return switch (layout) {
      MTLibraryLayout.grid => _MTGridSliver(
        itemCount: itemCount,
        itemBuilder: itemBuilder,
      ),
      MTLibraryLayout.cards when tablet => _MTColumnsSliver(
        minWidth: MTBreakpoint.cardColumn,
        spacing: MTSpace.lg,
        runSpacing: MTSpace.xl,
        itemCount: itemCount,
        itemBuilder: itemBuilder,
      ),
      // Cards carry no divider; the space is the divider.
      MTLibraryLayout.cards => SliverList.builder(
        itemCount: itemCount,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: MTSpace.lg),
          child: itemBuilder(context, index, null),
        ),
      ),
      MTLibraryLayout.compact when tablet => _MTColumnsSliver(
        minWidth: MTBreakpoint.compactColumn,
        spacing: MTSpace.xxl,
        runSpacing: 0,
        itemCount: itemCount,
        itemBuilder: itemBuilder,
      ),
      MTLibraryLayout.list when tablet => SliverLayoutBuilder(
        builder: (context, constraints) {
          final columns = MTMediaColumns.forWidth(
            constraints.crossAxisExtent,
            MediaQuery.textScalerOf(context),
            location: showLocation,
          );
          // Too narrow for a table, even on a tablet (a large font on a
          // small one): the phone's rows read better than a squeezed title.
          if (columns == null) return _rows();
          return SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(child: MTMediaRowHeader(columns: columns)),
              SliverList.builder(
                itemCount: itemCount,
                itemBuilder: (context, index) =>
                    itemBuilder(context, index, columns),
              ),
            ],
          );
        },
      ),
      _ => _rows(),
    };
  }

  Widget _rows() => SliverList.builder(
    itemCount: itemCount,
    itemBuilder: (context, index) => itemBuilder(context, index, null),
  );
}

/// The grid: as many columns as fit at 210 points at most, each cell
/// exactly as tall as its card.
///
/// **The height is measured, not a ratio.** A fixed 1.02 ratio was tuned on
/// a 411-point phone, where it fit a 16:9 cover, two title lines and a meta
/// line. But the cover grows with the cell and the text with the font, not
/// together: a 320-point phone or a font at 1.3 left the text short of room
/// and every cell overflowed (the device matrix, 2026-10-10). The cell is
/// now the cover for its width plus the text for the user's font.
class _MTGridSliver extends StatelessWidget {
  const _MTGridSliver({required this.itemCount, required this.itemBuilder});

  final int itemCount;
  final MTLibraryItemBuilder itemBuilder;

  static const double _maxCell = 210;
  static const double _gap = MTSpace.md;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.crossAxisExtent;
      // The same column count as Flutter's max-extent grid.
      final columns = math.max(1, (width / (_maxCell + _gap)).ceil());
      final cell = (width - _gap * (columns - 1)) / columns;
      return SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: _gap,
          crossAxisSpacing: _gap,
          mainAxisExtent: _cellHeight(context, cell),
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) => itemBuilder(context, index, null),
      );
    },
  );

  /// What [MTMediaGridCard] stacks in grid mode: its padding, a 16:9
  /// cover, a gap, two title lines, a gap and the meta line.
  static double _cellHeight(BuildContext context, double width) {
    final text = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context);
    double lines(TextStyle style, int count) {
      final painter = TextPainter(
        text: TextSpan(text: List.filled(count, 'Ag').join('\n'), style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: count,
      )..layout();
      final height = painter.height;
      painter.dispose();
      return height;
    }

    const pad = MTSpace.xxs;
    final title = text.bodySmall!.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.35,
    );
    return pad +
        (width - pad * 2) * 9 / 16 +
        MTSpace.xs +
        lines(title, 2) +
        3 +
        lines(text.labelSmall!, 1) +
        pad +
        // Rounding in the cover's layout, so the last pixel never spills.
        1;
  }
}

/// Items in as many equal columns as fit at [minWidth] each, built a row
/// at a time. A row of widgets rather than a grid, because a grid fixes
/// every cell's height and a title on two lines, or a large font, would
/// overflow it.
class _MTColumnsSliver extends StatelessWidget {
  const _MTColumnsSliver({
    required this.minWidth,
    required this.spacing,
    required this.runSpacing,
    required this.itemCount,
    required this.itemBuilder,
  });

  final double minWidth;
  final double spacing;
  final double runSpacing;
  final int itemCount;
  final MTLibraryItemBuilder itemBuilder;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final columns = math.max(
        1,
        ((constraints.crossAxisExtent + spacing) / (minWidth + spacing))
            .floor(),
      );
      return SliverList.builder(
        itemCount: (itemCount / columns).ceil(),
        itemBuilder: (context, row) => Padding(
          padding: EdgeInsets.only(bottom: runSpacing),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) SizedBox(width: spacing),
                Expanded(
                  child: row * columns + c < itemCount
                      ? itemBuilder(context, row * columns + c, null)
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
