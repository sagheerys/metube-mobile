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
    useRootNavigator: true,
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

/// **حالة محلية متفائلة** (بلاغ المالك 2026-09-02: «الوسوم لا تزال
/// تسبب ربكة»).
///
/// السبب كان في البناء لا في المنطق: الورقة كانت تقرأ الوسوم بـ
/// `FutureBuilder` وتُبطل `tagCountsProvider` عند **كل نقرة**. بين
/// النقرة ووصول القراءة الجديدة يكون `snapshot.data` فارغاً والعدّادات
/// مُبطَلة — فتُرسم الرقائق كلها **غير مُحدَّدة**، وبعضها يختفي تماماً،
/// ثم تعود بعد جزء من الثانية. النقرة الواحدة تبدو وكأنها ألغت كل شيء.
///
/// الآن: تُقرأ الحالة **مرة** عند الفتح، والنقرة تغيّر الحالة المحلية
/// فوراً وتكتب في الخلفية. لا وميض ولا انتظار.
class _ItemTagsSheetState extends ConsumerState<_ItemTagsSheet> {
  final TextEditingController _newTag = TextEditingController();

  /// كل الوسوم المعروضة (مرتّبة) — تشمل ما ليس على هذا التحديد.
  List<String> _all = const [];

  /// المطبَّقة على **كل** المحدد (الجماعي يوضح المشترك فقط).
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

  /// النقرة تُطبَّق محلياً فوراً، والكتابة تتبعها.
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
      // `toggleTag` يقلب الحالة، فلا يُستدعى إلا حين تختلف عن المطلوب.
      if (has != adding) await _tags.toggleTag(url, tag);
    }
    // **حارس مفقود (العطل ط-7):** وسم 30 عنصراً ثم إغلاق الورقة قبل
    // اكتمال الحلقة كان يستدعي `ref.invalidate` على ودجت ميت ⇒
    // `StateError` غير ملتقط. (`_load` المجاور محروس — هذه نُسيت.)
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

  /// المكتبة والعدّادات تتجدد **بعد** الكتابة — لا قبلها ولا أثناءها.
  void _refreshHost() {
    ref.invalidate(tagCountsProvider);
    ref.invalidate(libraryItemsProvider);
    // **وسطر «الوسوم» في التفاصيل والمشغلين**: الفهرس يقرأ `TagsIndex`
    // مرة، ولا شيء كان يُبطله بعد الكتابة — فيبقى السطر معروضاً بوسم
    // أُزيل للتو (فحص 2026-09-04).
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
              Text(l10n.noTagsYet,
                  style: Theme.of(context).textTheme.bodySmall)
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
        ),
      ),
    );
  }
}
