import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../playlists/playlists_providers.dart';

/// **Where an item belongs**: which playlists it is in and which tags it
/// carries.
///
/// Field report 2026-09-04: "in the clip details I want to see which
/// playlist it was added to, and which tag it is under". The information
/// was in the store and no screen displayed it.
///
/// **[tags] is always empty in Lite**, by design rather than by oversight:
/// tags are exclusively a Super feature, and Lite's index carries nothing
/// but the system favourites tag. The type is the same in both apps so the
/// shared screens stay identical.
class ItemMembership {
  const ItemMembership({this.playlists = const [], this.tags = const []});

  final List<String> playlists;
  final List<String> tags;

  bool get isEmpty => playlists.isEmpty && tags.isEmpty;

  /// One line ready to show under the title, or `null` when it belongs
  /// nowhere.
  String? line(MTLocalizations l10n) {
    final parts = [
      if (playlists.isNotEmpty)
        '${l10n.inPlaylists}: ${playlists.join(l10n.listSeparator)}',
      if (tags.isNotEmpty) '${l10n.tags}: ${tags.join(l10n.listSeparator)}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// **One index for the whole library, not a provider per item.**
///
/// A `family` would have meant a provider per clip along the reels path,
/// hundreds of them, all derived from the same read. The key is **the
/// unified library key**, the canonicalUrl when known and otherwise the
/// path, which is exactly what the playlist entries store.
final membershipIndexProvider = FutureProvider<Map<String, ItemMembership>>((
  ref,
) async {
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
