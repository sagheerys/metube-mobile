import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../playlists/playlists_providers.dart';

/// **انتماء العنصر**: في أي قوائم تشغيل هو، وتحت أي وسوم (م-16).
///
/// بلاغ المالك 2026-09-04: «أريد في تفاصيل المقطع في أي قائمة بلاي لست
/// إذا كان مضافاً، وإذا كان في وسم معين في أي وسم يتبع». المعلومة كانت
/// موجودة في المخزن ولا تعرضها أي شاشة.
///
/// **[tags] فارغة دائماً في Lite** بقصد لا سهواً: الوسوم ميزة Super
/// حصرياً (جدول الأدوار في CLAUDE.md §4)، وفهرس Lite لا يحمل غير وسم
/// المفضلة النظامي. النوع نفسه في التطبيقين كي تبقى الشاشات المشتركة
/// متماثلة.
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
/// وكلها تُشتق من القراءة نفسها. المفتاح هو **مفتاح المكتبة الموحد**
/// (canonicalUrl إن عُرف وإلا المسار) — نفس ما تخزنه مداخل القوائم.
final membershipIndexProvider =
    FutureProvider<Map<String, ItemMembership>>((ref) async {
  final playlists = await ref.watch(playlistsProvider.future);
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
  return {
    for (final MapEntry(:key, :value) in names.entries)
      key: ItemMembership(playlists: value),
  };
});
