import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/settings/resume_refresh.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';

/// **Returning to the app re-reads the library** (found 2026-09-25: the
/// arrivals notice promised to appear "when you return to the app", and
/// nothing re-read `/history` on a return, so neither the notice nor the
/// library moved until pulled by hand).
void main() {
  testWidgets('coming back from the background reads /history again', (
    tester,
  ) async {
    var reads = 0;
    final container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(const SuperSettings()),
        historyProvider.overrideWith((ref) async {
          reads++;
          return null;
        }),
      ],
    );
    addTearDown(container.dispose);
    // A listener keeps the provider alive; invalidating does not recompute
    // a provider nobody watches.
    container.listen(historyProvider, (_, _) {});
    container.read(resumeRefreshProvider);
    await tester.pump();
    expect(reads, 1);

    // The full sequence the framework requires: leaving, then returning.
    for (final state in const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));

    expect(reads, 2);
  });
}
