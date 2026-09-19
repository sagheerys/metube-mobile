import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/playlists/playlists_providers.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';

/// **Found 2026-09-19 while staging screenshots.** Favourites live in the
/// tags index as a system tag, and the counts that feed the library's
/// filter chips, "your tags" and the manage-tags sheet were the raw index:
/// with one real tag in place, the library offered `# __favorites__ 2` as a
/// filter beside it. Invisible to anyone with no tags — the chip row hides
/// itself when the map is empty — and permanent for anyone with one.
void main() {
  test('the favourites system tag is not one of the user\'s tags', () async {
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(const SuperSettings()),
        loggerProvider.overrideWithValue(
          MTLogger(filePath: '${Directory.systemTemp.path}/mtf_test.log'),
        ),
      ],
    );
    addTearDown(c.dispose);
    final tags = c.read(tagsIndexProvider);
    await tags.put('https://x/a', const [
      MTConstants.favoritesSystemTag,
      'calm',
    ]);
    await tags.put('https://x/b', const [MTConstants.favoritesSystemTag]);

    expect(await c.read(tagCountsProvider.future), {'calm': 1});
  });
}
