import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../playlists/playlists_providers.dart';

/// **انتماء العنصر**: في أي قوائم تشغيل هو، وتحت أي وسوم (م-16).
///
/// بلاغ المالك 2026-09-04: «أريد في تفاصيل المقطع في أي قائمة بلاي لست
/// إذا كان مضافاً، وإذا كان في وسم معين في أي وسم يتبع». المعلومة كانت
/// موجودة في المخزن ولا تعرضها أي شاشة.
///
/// نظيره في Lite بلا وسوم — الوسوم ميزة Super حصراً (CLAUDE.md §4).
class ItemMembership {
  const ItemMembership({
    this.playlists = const [],
    this.tags = const [],
  });

  final List<String> playlists;
  final List<String> tags;

  bool get isEmpty => playlists.isEmpty && tags.isEmpty;

  /// سطر واحد جاهز للعرض تحت العنوان — `null` إن لا انتماء له.
  String? line(MTLocalizations l10n) {
    final parts = [
      if (playlists.isNotEmpty) '${l10n.inPlaylists}: ${playlists.join('، ')}',
      if (tags.isNotEmpty) '${l10n.tags}: ${tags.join('، ')}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// **فهرس واحد للمكتبة كلها، لا مزوّد لكل عنصر.**
///
/// عائلة `family` كانت ستعني مزوّداً لكل مقطع في مسار الريلز (مئات)،
/// وكلها تُشتق من القراءتين نفسيهما. المفتاح canonicalUrl — نفس مفتاح
/// الوسوم ومداخل القوائم (القاعدة 3).
final membershipIndexProvider =
    FutureProvider<Map<String, ItemMembership>>((ref) async {
  final playlists = await ref.watch(playlistsProvider.future);
  final allTags = await ref.watch(tagsIndexProvider).readAll();

  final names = <String, List<String>>{};
  for (final playlist in playlists) {
    for (final entry in playlist.items) {
      final key = entry.canonicalUrl.isNotEmpty
          ? entry.canonicalUrl
          : (entry.legacyPath ?? '');
      if (key.isEmpty) continue;
      (names[key] ??= <String>[]).add(playlist.name);
    }
  }

  // وسم المفضلة نظامي ويُعرض بقلبه لا باسمه — لا يُحشر في سطر الوسوم.
  final tags = <String, List<String>>{
    for (final MapEntry(:key, :value) in allTags.entries)
      if (value.any((t) => t != MTConstants.favoritesSystemTag))
        key: (value.where((t) => t != MTConstants.favoritesSystemTag).toList()
          ..sort()),
  };

  return {
    for (final key in {...names.keys, ...tags.keys})
      key: ItemMembership(
        playlists: names[key] ?? const [],
        tags: tags[key] ?? const [],
      ),
  };
});
