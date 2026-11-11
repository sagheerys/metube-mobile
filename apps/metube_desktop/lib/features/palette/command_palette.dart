import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/library_data.dart';
import '../../data/saved_searches.dart';
import '../../data/transcripts_data.dart';
import '../../di.dart';
import '../../router.dart';
import '../../shell/focus_regions.dart';
import 'palette_grow.dart';
import 'palette_model.dart';
import 'palette_rows.dart';
import '../../shell/search_lens.dart';
import 'palette_keys.dart';

/// **The command palette** (Ctrl+K): it drops from the top of the window
/// and searches titles and what was said inside clips together, and runs
/// commands after `>`. The arrows move, Enter opens, Esc closes, so no
/// mouse is needed from the search to the clip.
///
/// Never two at once: Ctrl+K is ignored while a dialog is over the window,
/// and the barrier keeps the search box and sidebar from being clicked.
///
/// It opens out of the search box at [from] when the box is shown.
Future<void> showCommandPalette(
  BuildContext context, {
  required List<PaletteCommand> commands,
  String initial = '',
  Rect? from,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: MTThemeX.of(context).palette.ink.withValues(alpha: 0.18),
  transitionDuration: mtMotionDuration(
    context,
    from == null ? MTMotion.fast : MTMotion.reveal,
  ),
  pageBuilder: (_, _, _) => _Palette(commands: commands, initial: initial),
  transitionBuilder: (context, animation, _, child) =>
      paletteTransition(context, animation, from, child),
);

/// Plays [item] from [start], the moment the words were said, and opens
/// its page when it has a picture.
Future<void> playFromMoment(
  WidgetRef ref,
  GoRouter router,
  LibraryItem item,
  Duration start,
) async {
  final player = ref.read(playerProvider);
  await player.setLooping(false);
  await player.playItems([toPlaylistItem(item)]);
  await player.seek(start);
  if (!item.isAudio) router.go(EmberRoutes.item(item.canonicalUrl));
}

class _Palette extends ConsumerStatefulWidget {
  const _Palette({required this.commands, required this.initial});

  final List<PaletteCommand> commands;
  final String initial;

  @override
  ConsumerState<_Palette> createState() => _PaletteState();
}

class _PaletteState extends ConsumerState<_Palette> {
  late final _query = TextEditingController(text: widget.initial)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initial.length,
    );
  final _scroll = ScrollController();
  final _keys = <int, GlobalKey>{};

  /// What each row says to a screen reader when the arrows reach it.
  final _spoken = <int, String>{};
  var _selected = 0;

  /// Rows before this open a page (titles, then lines said), entered once
  /// the palette is fully gone: any sooner, the closing route takes focus.
  var _pages = 0;
  FocusNode? _enter;

  @override
  void dispose() {
    if (_enter case final page?) focusFirstIn(page);
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  PaletteResults _results() {
    final saved = ref.watch(savedSearchesProvider).valueOrNull ?? const [];
    return paletteResults(
      query: _query.text,
      items: ref.watch(libraryItemsProvider).valueOrNull ?? const [],
      commands: widget.commands,
      index: ref.watch(transcriptIndexProvider).valueOrNull,
      savedQueries: {for (final s in saved) s.query},
    );
  }

  /// Every row Enter can open, in the order they are drawn.
  List<VoidCallback> _actions(PaletteResults r) {
    final router = GoRouter.of(context);
    return [
      for (final item in r.titles)
        () => router.go(EmberRoutes.item(item.canonicalUrl)),
      for (final match in r.said)
        () =>
            unawaited(playFromMoment(ref, router, match.item, match.hit.start)),
      for (final command in r.commands) command.run,
      if (r.canSave) _save,
    ];
  }

  void _save() {
    final query = _query.text.trim();
    unawaited(ref.read(savedSearchesProvider.notifier).add(query));
    showMTNotice(context, message: context.mtl.desktopSearchSaved);
  }

  void _run(List<VoidCallback> actions, int index) {
    if (index < _pages) _enter = ref.read(contentFocusProvider);
    final action = actions[index];
    Navigator.of(context).pop();
    action();
  }

  void _move(int by, int count) {
    if (count == 0) return;
    setState(() => _selected = (_selected + by) % count);
    if (_spoken[_selected] case final said?) announceRow(context, said);
    final key = _keys[_selected];
    if (key?.currentContext case final row?) {
      unawaited(
        Scrollable.ensureVisible(
          row,
          duration: mtMotionDuration(context, MTMotion.fast),
          alignmentPolicy: by > 0
              ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
              : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        ),
      );
    }
  }

  GlobalKey _keyOf(int index) => _keys[index] ??= GlobalKey();

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final results = _results();
    final actions = _actions(results);
    _pages = results.titles.length + results.said.length;
    if (_selected >= actions.length) _selected = 0;
    var row = 0;
    Widget pick(String spoken, Widget Function(bool selected) build) {
      final index = row++;
      _spoken[index] = spoken;
      return KeyedSubtree(
        key: _keyOf(index),
        child: PaletteRowTap(
          onTap: () => _run(actions, index),
          selected: index == _selected,
          child: build(index == _selected),
        ),
      );
    }

    void open() {
      if (actions.isNotEmpty) _run(actions, _selected);
    }

    final query = _query.text.trim();
    // Placed by `paletteTransition`: out of the search box, or at the top.
    return Material(
      color: p.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MTCorners.desktop.card),
        side: BorderSide(color: p.line2, width: MTThemeX.of(context).hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Enter is taken here as a key, before the text field's
          // own submit, so it opens the chosen row exactly once.
          CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                  _move(1, actions.length),
              const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                  _move(-1, actions.length),
              const SingleActivator(LogicalKeyboardKey.enter): open,
              const SingleActivator(LogicalKeyboardKey.numpadEnter): open,
            },
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                MTSpace.md,
                PaletteFieldTop.of(context),
                MTSpace.md,
                MTSpace.md,
              ),
              child: TextField(
                controller: _query,
                autofocus: true,
                onChanged: (_) => setState(() => _selected = 0),
                decoration: InputDecoration(
                  hintText: l.desktopPaletteHint,
                  prefixIcon: searchLens(p),
                ),
              ),
            ),
          ),
          Flexible(
            child: results.isEmpty
                ? const PaletteEmpty()
                : ListView(
                    controller: _scroll,
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: MTSpace.sm),
                    children: [
                      if (results.titles.isNotEmpty)
                        PaletteHeader(l.desktopPaletteTitles),
                      for (final item in results.titles)
                        pick(
                          TitleRow.spoken(l, item),
                          (on) => TitleRow(item: item, selected: on),
                        ),
                      if (results.said.isNotEmpty)
                        PaletteHeader(l.desktopPaletteSaid),
                      for (final match in results.said)
                        pick(
                          SaidRow.spoken(l, match),
                          (on) =>
                              SaidRow(match: match, query: query, selected: on),
                        ),
                      if (results.commands.isNotEmpty)
                        PaletteHeader(l.desktopPaletteCommands),
                      for (final command in results.commands)
                        pick(
                          command.label,
                          (on) => CommandRow(
                            icon: command.icon,
                            label: command.label,
                            selected: on,
                          ),
                        ),
                      if (results.canSave)
                        pick(
                          l.desktopPaletteSave,
                          (on) => CommandRow(
                            icon: MTIcons.plus,
                            label: l.desktopPaletteSave,
                            selected: on,
                          ),
                        ),
                    ],
                  ),
          ),
          Divider(height: 1, color: p.line),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MTSpace.md,
              vertical: MTSpace.xs,
            ),
            child: const PaletteKeys(),
          ),
        ],
      ),
    );
  }
}
