import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';
import 'mt_adaptive.dart';

/// One group of the settings home: a small heading over its rows. The phone
/// draws a hairline between rows; the tablet's narrow list leaves them out,
/// since the lit row already marks its place.
class MTSettingsGroup extends StatelessWidget {
  const MTSettingsGroup({
    super.key,
    required this.title,
    required this.rows,
    this.divided = true,
  });

  final String title;
  final List<Widget> rows;
  final bool divided;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            MTSpace.md,
            MTSpace.lg,
            MTSpace.md,
            MTSpace.xs,
          ),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelSmall!
                .copyWith(color: p.ink3, letterSpacing: 0.8),
          ),
        ),
        for (var i = 0; i < rows.length; i++) ...[
          if (divided && i > 0) Divider(height: 1, color: p.line),
          rows[i],
        ],
      ],
    );
  }
}

/// One section of the settings: its icon, its name, and **the setting as it
/// stands** beneath, so the home page answers "how is this set?" without
/// opening anything. On the tablet's list the open section is lit in the
/// accent and there is no chevron, since nothing is pushed.
class MTSettingsRow extends StatelessWidget {
  const MTSettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.selected = false,
    this.chevron = true,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final bool selected;
  final bool chevron;

  static const _side = 36.0;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    // **Its own surface**: a tile's colour is painted on the nearest
    // Material, and on the page's it stayed where the row used to be when
    // the server card above grew a line after loading.
    return Material(type: MaterialType.transparency, child: _tile(context, p));
  }

  Widget _tile(BuildContext context, MTPalette p) {
    return ListTile(
      selected: selected,
      selectedTileColor: p.accentSoft,
      selectedColor: p.accentInk,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MTRadius.card),
      ),
      contentPadding: const EdgeInsetsDirectional.symmetric(
        horizontal: MTSpace.sm,
      ),
      leading: Container(
        width: _side,
        height: _side,
        decoration: BoxDecoration(
          // On the lit row the tile would vanish into the same tint.
          color: selected ? p.bg : p.accentSoft,
          borderRadius: BorderRadius.circular(MTRadius.thumb),
        ),
        child: Icon(icon, size: 20, color: p.accentInk),
      ),
      title: Text(
        title,
        style: selected ? const TextStyle(fontWeight: FontWeight.w700) : null,
      ),
      subtitle: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall!.copyWith(color: p.ink3),
      ),
      trailing: chevron
          ? Icon(Icons.chevron_right_rounded, color: p.ink3)
          : null,
      onTap: onTap,
    );
  }
}

/// A section's own page: its title on top and its fields at a readable
/// width, the same on a phone and in the tablet's open pane.
class MTSettingsPage extends StatelessWidget {
  const MTSettingsPage({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), actions: actions),
    body: MTReadableWidth(
      child: ListView(
        // Room above the first field's floating label, which a page title
        // sits right on top of, and below for the system bar.
        padding: const EdgeInsets.fromLTRB(
          MTSpace.pagePad,
          MTSpace.md,
          MTSpace.pagePad,
          120,
        ),
        children: [child],
      ),
    ),
  );
}
