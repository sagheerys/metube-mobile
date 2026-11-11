import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import 'key_cap.dart';
import 'nav_history.dart';

/// The title bar's tools, over the content: back and forward, the search
/// box, the downloads, and the button that shows or hides the side panel.
///
/// Its bare stretches belong to the title bar beneath, so they move the
/// window: nothing here paints a ground of its own.
class EmberContentBar extends StatelessWidget {
  const EmberContentBar({
    super.key,
    required this.history,
    required this.onSearch,
    required this.panelShown,
    required this.onTogglePanel,
    this.downloads,
    this.searchKey,
  });

  final NavHistory history;
  final VoidCallback onSearch;

  /// Marks the search box, which the palette opens out of; a narrow bar
  /// shows a button instead and leaves it unattached.
  final GlobalKey? searchKey;
  final bool panelShown;
  final VoidCallback onTogglePanel;

  /// The downloads button, before the panel toggle.
  final Widget? downloads;

  /// Below this the search box would cut its own hint to nothing, so the
  /// search is a button, as the other tools are.
  static const searchBoxMin = MTBreakpoint.readable / 4;

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: MTSpace.xl,
        end: MTSpace.sm,
      ),
      child: Row(
        children: [
          ListenableBuilder(
            listenable: history,
            // The arrows point the way the page turns: in Arabic "back"
            // points right.
            builder: (context, _) => Row(
              children: [
                _BarButton(
                  icon: MTIcons.back,
                  label: l.desktopBack,
                  shortcut: 'Alt+←',
                  onTap: history.canGoBack ? history.back : null,
                  mirrored: true,
                ),
                _BarButton(
                  icon: MTIcons.forward,
                  label: l.desktopForward,
                  shortcut: 'Alt+→',
                  onTap: history.canGoForward ? history.forward : null,
                  mirrored: true,
                ),
              ],
            ),
          ),
          const SizedBox(width: MTSpace.sm),
          // Three parts of the room to the search, one kept bare to take
          // hold of the window by.
          Flexible(
            flex: 3,
            child: LayoutBuilder(
              builder: (context, box) => box.maxWidth < searchBoxMin
                  ? Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _BarButton(
                        icon: MTIcons.search,
                        label: l.desktopSearch,
                        shortcut: 'Ctrl+K',
                        onTap: onSearch,
                      ),
                    )
                  : Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: MTBreakpoint.readable / 2,
                        ),
                        child: _SearchBox(
                          key: searchKey,
                          hint: l.desktopSearchHint,
                          onTap: onSearch,
                        ),
                      ),
                    ),
            ),
          ),
          const Spacer(),
          ?downloads,
          _BarButton(
            icon: MTIcons.transcript,
            label: panelShown ? l.desktopHidePanel : l.desktopShowPanel,
            onTap: onTogglePanel,
            selected: panelShown,
          ),
        ],
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.shortcut,
    this.selected = false,
    this.mirrored = false,
  });

  final MTIconData icon;
  final String label;
  final String? shortcut;
  final VoidCallback? onTap;
  final bool selected;

  /// An arrow that turns with the reading direction.
  final bool mirrored;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final ink = onTap == null ? p.ink3 : (selected ? p.ink : p.ink2);
    return MTShortcutTooltip(
      message: label,
      shortcut: shortcut,
      // Space each side, as in the player bar: two veils never touch.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: MTSpace.xxs / 2),
        child: _button(context, ink),
      ),
    );
  }

  Widget _button(BuildContext context, Color ink) => IconButton(
    onPressed: onTap,
    isSelected: selected,
    icon: Transform.flip(
      flipX: mirrored && Directionality.of(context) == TextDirection.rtl,
      child: MTIcon(
        icon,
        size: MTDensity.desktop.icon,
        color: ink,
        semanticLabel: label,
      ),
    ),
  );
}

/// Looks like a field and opens the search place; the real search, with
/// its command palette, comes with the search screen.
class _SearchBox extends StatelessWidget {
  const _SearchBox({super.key, required this.hint, required this.onTap});

  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final corners = MTCorners.desktop;
    return Semantics(
      button: true,
      label: hint,
      excludeSemantics: true,
      child: Material(
        color: p.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(corners.field),
          side: BorderSide(
            color: p.line2,
            width: MTThemeX.of(context).hairline,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: MTDensity.desktop.row,
            child: Row(
              children: [
                const SizedBox(width: MTSpace.md),
                MTIcon(
                  MTIcons.search,
                  size: MTDensity.desktop.icon,
                  color: p.ink3,
                ),
                const SizedBox(width: MTSpace.sm),
                Expanded(
                  child: Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(color: p.ink3),
                  ),
                ),
                const KeyCap(label: 'Ctrl K'),
                const SizedBox(width: MTSpace.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
