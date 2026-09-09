import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../playlists/playlists_providers.dart';

/// **Where an item belongs**: which playlists it is in and which tags it
/// carries.
///
/// Field report 2026-09-04: "in the clip details I want to see which
/// playlist it was added to, and which tag it is under". The information
/// was in the store and no screen displayed it.
///
/// Its Lite counterpart has no tags; tags are a Super feature only.
class ItemMembership {
  const ItemMembership({this.playlists = const [], this.tags = const []});

  final List<String> playlists;
  final List<String> tags;

  bool get isEmpty => playlists.isEmpty && tags.isEmpty;

  /// One line ready to show under the title, or `null` when it belongs
  /// nowhere.
  String? line(MTLocalizations l10n) {
    final parts = [
      if (playlists.isNotEmpty) '${l10n.inPlaylists}: ${playlists.join('، ')}',
      if (tags.isNotEmpty) '${l10n.tags}: ${tags.join('، ')}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// **One index for the whole library, not a provider per item.**
///
/// A `family` would have meant a provider per clip along the reels path,
/// hundreds of them, all derived from the same two reads. The key is the
/// canonicalUrl, the same key as the tags and the playlist entries (rule
/// 3).
final membershipIndexProvider = FutureProvider<Map<String, ItemMembership>>((
  ref,
) async {
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

  // The favourites tag is a system tag shown by its heart rather than by
  // its name, so it is not squeezed into the tag line.
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
