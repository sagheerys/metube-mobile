import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/features/transcripts/subtitles.dart';
import 'package:mt_core/mt_core.dart';

/// A restored backup rewrites the subtitle keys under the running app. The
/// settings page and the players must show what was restored, not what
/// was there before, without a restart.
void main() {
  test('reload shows what a restore wrote, on the same notifiers', () async {
    final store = MemoryKeyValueStore();
    final prefs = SubtitlePrefs(store);
    addTearDown(prefs.dispose);
    await pumpEventQueue();
    final shown = prefs.shown;
    expect(shown.value, isFalse);

    // What a restore does: the store changes, the app keeps running.
    await store.setBool('subtitles_shown', true);
    await store.setInt('subtitles_size', 2);
    await prefs.reload();

    expect(identical(prefs.shown, shown), isTrue);
    expect(prefs.shown.value, isTrue);
    expect(prefs.size.value, 2);
  });
}
