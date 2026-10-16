part of 'mt_media_row.dart';

/// Which columns a library table shows. Decided once from the width the
/// header and the rows share, so every column lines up under its title.
class MTMediaColumns {
  const MTMediaColumns({
    this.size = false,
    this.added = false,
    this.location = false,
  });

  final bool size;
  final bool added;
  final bool location;

  static const double thumbWidth = 112;
  static const double thumbHeight = 63;

  // Text columns are measured at a text scale of 1 and grow with the
  // user's font, so a large font drops a column instead of clipping it.
  static const double _length = 56;
  static const double _size = 72;
  static const double _added = 112;
  static const double _location = 96;
  static const double _actions = 88;
  static const double _titleMin = 220;

  static double _gap(int count) => MTSpace.lg * count;

  /// The columns that fit [width], dropping the least useful first: the
  /// date, then the size. Null when even the title would be squeezed below
  /// a readable width; the caller then keeps the phone's row.
  static MTMediaColumns? forWidth(
    double width,
    TextScaler scaler, {
    required bool location,
  }) {
    double s(double w) => scaler.scale(w);
    var used = thumbWidth + s(_length) + _actions + _gap(3);
    if (location) used += s(_location) + _gap(1);
    if (width - used < _titleMin) return null;
    final size = width - used - s(_size) - _gap(1) >= _titleMin;
    if (size) used += s(_size) + _gap(1);
    final added = size && width - used - s(_added) - _gap(1) >= _titleMin;
    return MTMediaColumns(size: size, added: added, location: location);
  }
}

/// The cells after the title, shared by the header and the rows so the two
/// cannot drift apart.
List<Widget> _cells(
  BuildContext context,
  MTMediaColumns columns, {
  required Widget length,
  required Widget size,
  required Widget added,
  required Widget location,
  required Widget actions,
}) {
  final scaler = MediaQuery.textScalerOf(context);
  Widget cell(double width, Widget child) => Padding(
    padding: const EdgeInsetsDirectional.only(start: MTSpace.lg),
    child: SizedBox(width: scaler.scale(width), child: child),
  );
  return [
    cell(MTMediaColumns._length, length),
    if (columns.size) cell(MTMediaColumns._size, size),
    if (columns.added) cell(MTMediaColumns._added, added),
    if (columns.location) cell(MTMediaColumns._location, location),
    Padding(
      padding: const EdgeInsetsDirectional.only(start: MTSpace.lg),
      child: SizedBox(width: MTMediaColumns._actions, child: actions),
    ),
  ];
}

Widget _figure(String? value, TextStyle style) => Text(
  value == null ? '' : mtLtrRun(value),
  maxLines: 1,
  softWrap: false,
  overflow: TextOverflow.fade,
  textAlign: TextAlign.end,
  style: style,
);

/// The titles over a library table.
class MTMediaRowHeader extends StatelessWidget {
  const MTMediaRowHeader({super.key, required this.columns});

  final MTMediaColumns columns;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final l10n = context.mtl;
    final style = Theme.of(context).textTheme.labelSmall!
        .copyWith(color: p.ink3, letterSpacing: 0.6);
    Text label(String text, {TextAlign align = TextAlign.start}) => Text(
      text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.fade,
      textAlign: align,
      style: style,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(
        MTSpace.xs,
        MTSpace.xs,
        MTSpace.xs,
        MTSpace.sm,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.line2)),
      ),
      child: Row(
        children: [
          const SizedBox(width: MTMediaColumns.thumbWidth + MTSpace.lg),
          Expanded(child: label(l10n.titleLabel)),
          ..._cells(
            context,
            columns,
            length: label(l10n.columnLength, align: TextAlign.end),
            size: label(l10n.size, align: TextAlign.end),
            added: label(l10n.columnAdded),
            location: label(l10n.source),
            actions: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
