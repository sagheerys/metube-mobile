import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../library/library_providers.dart';
import '../playlists/playlists_providers.dart';
import '../shared/membership.dart';
import 'manage_tags_sheet.dart';

/// The item tags sheet: toggle existing tags, create a tag, and a "manage
/// tags" button. It works on a single item or on a multi-selection (rule
/// 6).
void showItemTagsSheet(
  BuildContext context,
  WidgetRef ref,
  List<String> canonicalUrls,
) {
  if (canonicalUrls.isEmpty) return;
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => _ItemTagsSheet(canonicalUrls: canonicalUrls, host: context),
  );
}

class _ItemTagsSheet extends ConsumerStatefulWidget {
  const _ItemTagsSheet({required this.canonicalUrls, required this.host});

  final List<String> canonicalUrls;

  /// The hosting screen's context, used to open the management sheet after
  /// this one closes.
  final BuildContext host;

  @override
  ConsumerState<_ItemTagsSheet> createState() => _ItemTagsSheetState();
}

/// **Optimistic local state** (field report 2026-09-02: "the tags still
/// cause confusion").
///
/// The cause was in the build, not the logic: the sheet read the tags with
/// a `FutureBuilder` and invalidated `tagCountsProvider` on **every tap**.
/// Between the tap and the new read arriving, `snapshot.data` was empty and
/// the counters invalidated, so every chip was drawn **unselected**, some
/// disappeared entirely, and they came back a fraction of a second later. A
/// single tap looked as though it had undone everything.
///
/// Now the state is read **once** on opening, and a tap changes the local
/// state immediately and writes in the background. No flicker and no wait.
class _ItemTagsSheetState extends ConsumerState<_ItemTagsSheet> {
  final TextEditingController _newTag = TextEditingController();

  /// Every tag on display, sorted, including those not on this selection.
  List<String> _all = const [];

  /// Those applied to **all** of the selection; a bulk edit shows only what
  /// is common.
  Set<String> _selected = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _newTag.dispose();
    super.dispose();
  }

  TagsIndex get _tags => ref.read(tagsIndexProvider);

  Future<void> _load() async {
    final all = await _tags.readAll();
    Set<String>? common;
    for (final url in widget.canonicalUrls) {
      final tags = (all[url] ?? const <String>[])
          .where((t) => t != MTConstants.favoritesSystemTag)
          .toSet();
      common = common == null ? tags : common.intersection(tags);
    }
    final every = <String>{
      for (final tags in all.values)
        for (final tag in tags)
          if (tag != MTConstants.favoritesSystemTag) tag,
    };
    if (!mounted) return;
    setState(() {
      _all = (every..addAll(common ?? const {})).toList()..sort();
      _selected = common ?? {};
      _loading = false;
    });
  }

  /// The tap is applied locally at once, and the write follows it.
  Future<void> _toggle(String tag) async {
    final adding = !_selected.contains(tag);
    setState(() {
      if (adding) {
        _selected = {..._selected, tag};
        if (!_all.contains(tag)) _all = [..._all, tag]..sort();
      } else {
        _selected = {..._selected}..remove(tag);
      }
    });
    for (final url in widget.canonicalUrls) {
      final has = (await _tags.tagsOf(url)).contains(tag);
      // `toggleTag` flips the state, so it is only called when the state
      // differs from what is wanted.
      if (has != adding) await _tags.toggleTag(url, tag);
    }
    // **A missing guard:** tagging 30 items and then closing
    // the sheet before the loop finished called `ref.invalidate` on a dead
    // widget, an uncaught `StateError`. The neighbouring `_load` was
    // guarded; this one had been forgotten.
    if (!mounted) return;
    _refreshHost();
  }

  Future<void> _createTag() async {
    final name = _newTag.text.trim();
    if (name.isEmpty ||
        name == MTConstants.favoritesSystemTag ||
        _selected.contains(name)) {
      _newTag.clear();
      return;
    }
    _newTag.clear();
    await _toggle(name);
  }

  /// The library and the counters refresh **after** the write, never before
  /// or during it.
  void _refreshHost() {
    ref.invalidate(tagCountsProvider);
    ref.invalidate(libraryItemsProvider);
    // **And the tags line in the details and both players**: the index
    // reads `TagsIndex` once and nothing invalidated it after a write, so
    // the line kept showing a tag that had just been removed (review
    // 2026-09-04).
    ref.invalidate(membershipIndexProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: MTSpace.pagePad,
          right: MTSpace.pagePad,
          top: MTSpace.pagePad,
          bottom: MediaQuery.viewInsetsOf(context).bottom + MTSpace.pagePad,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MTSectionHeader(
              title: l10n.tags,
              trailing: l10n.queueItemsCount(widget.canonicalUrls.length),
            ),
            const SizedBox(height: MTSpace.md),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(MTSpace.md),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_all.isEmpty)
              Text(l10n.noTagsYet, style: Theme.of(context).textTheme.bodySmall)
            else
              Wrap(
                spacing: MTSpace.xs + 1,
                runSpacing: MTSpace.xs + 1,
                children: [
                  for (final tag in _all)
                    FilterChip(
                      label: Text('# $tag'),
                      selected: _selected.contains(tag),
                      showCheckmark: false,
                      onSelected: (_) => _toggle(tag),
                    ),
                ],
              ),
            const SizedBox(height: MTSpace.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newTag,
                    decoration: InputDecoration(hintText: l10n.newTagHint),
                    onSubmitted: (_) => _createTag(),
                  ),
                ),
                const SizedBox(width: MTSpace.xs),
                FilledButton(onPressed: _createTag, child: Text(l10n.create)),
              ],
            ),
            const SizedBox(height: MTSpace.sm),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                showManageTagsSheet(widget.host, ref);
              },
              icon: const Icon(Icons.settings_rounded, size: 17),
              label: Text(l10n.manageTags),
            ),
          ],
        ),
      ),
    );
  }
}
