import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'network_screen.dart';
import 'widgets/server_status_card.dart';

/// **The status card was lying** (review 2026-09-06):
/// `serverStatusProvider` is a provider with no `autoDispose` and no
/// timer, computed once and then kept, so if the server went down after
/// the last probe the card stayed "connected" until the user pressed
/// refresh.
///
/// Returning to the app is the right moment to ask again: it is cheap, one
/// request, and it falls exactly when the user is looking at the screen.
/// And we add no periodic timer: probing every minute wakes the network
/// with nobody watching.
final statusRefreshProvider = Provider<void>((ref) {
  final listener = AppLifecycleListener(
    onResume: () {
      ref.invalidate(serverStatusProvider);
      ref.invalidate(endpointsStatusProvider);
    },
  );
  ref.onDispose(listener.dispose);
});
