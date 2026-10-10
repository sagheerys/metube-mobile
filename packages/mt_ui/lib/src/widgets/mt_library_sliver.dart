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
      // **The ratio is measured, not estimated** (verified with an
      // emulator screenshot): 0.82 left about 50 points of dead space under
      // every card. The real content is a 16:9 cover plus two title lines
      // plus a meta line. A wide window simply gains columns.
      MTLibraryLayout.grid => SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 210,
          mainAxisSpacing: MTSpace.md,
          crossAxisSpacing: MTSpace.md,
          childAspectRatio: 1.02,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) => itemBuilder(context, index, null),
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
