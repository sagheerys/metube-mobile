import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di.dart';
import 'network_screen.dart';
import 'widgets/server_status_card.dart';

/// **Returning to the app asks the server again** — for the status card,
/// and for the library.
///
/// The card first (review 2026-09-06): `serverStatusProvider` has no
/// `autoDispose` and no timer, computed once and then kept, so if the
/// server went down after the last probe it said "connected" until the
/// user pressed refresh.
///
/// The library since 2026-09-25, found while explaining the arrivals
/// notice: it promised to appear "when you return to the app" and could
/// not, because nothing re-read `/history` on a return. Android keeps the
/// app in the background for hours, so a return is exactly where a
/// subscription's clips have most likely landed — and the library was
/// stale until pulled by hand. Lite has re-read its folder on return all
/// along.
///
/// Returning is the right moment: cheap, one request each, and it falls
/// exactly when the user is looking at the screen. No periodic timer:
/// probing every minute wakes the network with nobody watching.
final resumeRefreshProvider = Provider<void>((ref) {
  final listener = AppLifecycleListener(
    onResume: () {
      ref.invalidate(serverStatusProvider);
      ref.invalidate(endpointsStatusProvider);
      ref.invalidate(historyProvider);
    },
  );
  ref.onDispose(listener.dispose);
});
