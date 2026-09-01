import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../library/library_providers.dart';
import '../playlists/playlists_providers.dart';
import 'manage_tags_sheet.dart';

/// ورقة وسوم العنصر (م-26 · ر-7 خطوة 3): تبديل وسوم موجودة، إنشاء وسم،
/// وزر «إدارة الوسوم». تعمل على عنصر واحد أو تحديد جماعي (ر-6).
void showItemTagsSheet(
  BuildContext context,
  WidgetRef ref,
  List<String> canonicalUrls,
) {
  if (canonicalUrls.isEmpty) return;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        _ItemTagsSheet(canonicalUrls: canonicalUrls, host: context),
  );
}

class _ItemTagsSheet extends ConsumerStatefulWidget {
  const _ItemTagsSheet({required this.canonicalUrls, required this.host});

  final List<String> canonicalUrls;

  /// سياق الشاشة المستضيفة — تُفتح به ورقة الإدارة بعد إغلاق هذه.
  final BuildContext host;

  @override
  ConsumerState<_ItemTagsSheet> createState() => _ItemTagsSheetState();
}

class _ItemTagsSheetState extends ConsumerState<_ItemTagsSheet> {
  final TextEditingController _newTag = TextEditingController();

  @override
  void dispose() {
    _newTag.dispose();
    super.dispose();
  }

  TagsIndex get _tags => ref.read(tagsIndexProvider);

  /// الوسوم المطبقة على **كل** المحدد (الجماعي يوضح المشترك فقط).
  Future<Set<String>> _commonTags() async {
    Set<String>? common;
    for (final url in widget.canonicalUrls) {
      final tags = (await _tags.tagsOf(url))
          .where((t) => t != MTConstants.favoritesSystemTag)
          .toSet();
      common = common == null ? tags : common.intersection(tags);
    }
    return common ?? {};
  }

  Future<void> _toggle(String tag, bool selected) async {
    for (final url in widget.canonicalUrls) {
      final current = await _tags.tagsOf(url);
      final has = current.contains(tag);
      if (selected && has) await _tags.toggleTag(url, tag);
      if (!selected && !has) await _tags.toggleTag(url, tag);
    }
    _refresh();
  }

  Future<void> _createTag() async {
    final name = _newTag.text.trim();
    if (name.isEmpty || name == MTConstants.favoritesSystemTag) return;
    _newTag.clear();
    await _toggle(name, false);
  }

  void _refresh() {
    ref.invalidate(tagCountsProvider);
    ref.invalidate(libraryItemsProvider);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final counts = ref.watch(tagCountsProvider).value ?? const {};

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: MTSpace.pagePad,
          right: MTSpace.pagePad,
          top: MTSpace.pagePad,
          bottom: MediaQuery.viewInsetsOf(context).bottom + MTSpace.pagePad,
        ),
        child: FutureBuilder<Set<String>>(
          future: _commonTags(),
          builder: (context, snapshot) {
            final selected = snapshot.data ?? const <String>{};
            final all = {...counts.keys, ...selected}.toList()..sort();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MTSectionHeader(
                  title: l10n.tags,
                  trailing: l10n.queueItemsCount(widget.canonicalUrls.length),
                ),
                const SizedBox(height: MTSpace.md),
                if (all.isEmpty)
                  Text(l10n.noTagsYet,
                      style: Theme.of(context).textTheme.bodySmall)
                else
                  Wrap(
                    spacing: MTSpace.xs + 1,
                    runSpacing: MTSpace.xs + 1,
                    children: [
                      for (final tag in all)
                        FilterChip(
                          label: Text('# $tag'),
                          selected: selected.contains(tag),
                          showCheckmark: false,
                          onSelected: (_) =>
                              _toggle(tag, selected.contains(tag)),
                        ),
                    ],
                  ),
                const SizedBox(height: MTSpace.md),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newTag,
                        decoration:
                            InputDecoration(hintText: l10n.newTagHint),
                        onSubmitted: (_) => _createTag(),
                      ),
                    ),
                    const SizedBox(width: MTSpace.xs),
                    FilledButton(
                      onPressed: _createTag,
                      child: Text(l10n.create),
                    ),
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
            );
          },
        ),
      ),
    );
  }
}
