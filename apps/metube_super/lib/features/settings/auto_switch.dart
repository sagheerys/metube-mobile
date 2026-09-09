import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../../di.dart';
import 'settings_state.dart';

/// **Endpoint switching, as actually implemented.**
///
/// A defect caught on a real device (2026-09-01): only the *display* and
/// the *manual switch* had been built. `connectivity_plus` was declared in
/// the packages and imported in no file, there was no listener for network
/// changes, and `adoptActiveUrl` was called only by a tap in the network
/// screen. The result on a home network: the phone was beside the server
/// and still streamed through a Cloudflare tunnel, **41x slower** by
/// measurement (2MB: 2.3s locally against 94.8s through the tunnel).
///
/// The three triggers: a network change (Wi-Fi, mobile data,
/// disconnection), the app returning to the foreground (the network may
/// have changed while it was in the background), and startup.
class AutoSwitchService {
  AutoSwitchService(
    this._ref, {
    Stream<Object?>? networkChanges,
    this.debounce = const Duration(milliseconds: 700),
  }) : _changes = networkChanges ?? Connectivity().onConnectivityChanged;

  final Ref _ref;
  final Stream<Object?> _changes;

  /// Network changes arrive in **bursts** (loss, then connection, then
  /// address), so without debouncing we fire three parallel probes for one
  /// event.
  final Duration debounce;

  StreamSubscription<Object?>? _sub;
  AppLifecycleListener? _lifecycle;
  Timer? _timer;
  bool _running = false;
  bool _pending = false;

  /// The last endpoint adopted automatically, for the status card and for
  /// diagnostics.
  String? lastAdopted;

  void start() {
    _sub = _changes.listen((_) => schedule());
    _lifecycle = AppLifecycleListener(onResume: schedule);
    schedule(immediate: true);
  }

  /// **Debouncing lives here rather than in the execution:** the library
  /// polls every two seconds and invalidates
  /// `historyProvider`, and the error listener used to schedule a probe on
  /// **every** failure. A 700ms debounce is shorter than two seconds and so
  /// gathers nothing: a broken server plus an open library screen meant
  /// probing every endpoint every two seconds without pause, with new
  /// clients and a 4s timeout. Scheduled probes are now at least
  /// [minInterval] apart, and only the immediate trigger, startup, is
  /// exempt.
  void schedule({bool immediate = false}) {
    _timer?.cancel();
    if (immediate) {
      _timer = Timer(Duration.zero, () => unawaited(resolveNow()));
      return;
    }
    final since = _lastRun == null
        ? null
        : DateTime.now().difference(_lastRun!);
    final wait = since == null || since >= minInterval
        ? debounce
        : minInterval - since;
    _timer = Timer(wait, () => unawaited(resolveNow()));
  }

  /// Probes every candidate in parallel and adopts the first to respond,
  /// local first. It does nothing when switching is off or no endpoints are
  /// registered. The minimum gap between two **scheduled** probes is in
  /// [schedule].
  static const minInterval = Duration(seconds: 20);
  DateTime? _lastRun;

  Future<void> resolveNow() async {
    final settings = _ref.read(settingsProvider);
    if (!settings.autoSwitch) return;
    // **No switching while work is in flight:** switching the
    // endpoint rebuilds the engine and silently destroys all of its tasks.
    // Waiting until the queue is quiet is kinder than a download lost with
    // no message.
    final engine = _ref.read(downloadEngineProvider);
    if (engine != null && engine.hasActiveWork) {
      // It retries itself: no other listener will wake us when the queue
      // goes quiet.
      _timer?.cancel();
      _timer = Timer(minInterval, () => unawaited(resolveNow()));
      return;
    }
    _lastRun = DateTime.now();
    final candidates = settings.candidateUrls;
    if (candidates.isEmpty) return;
    // One candidate and it is already the active one, so there is nothing
    // to switch and no reason to probe.
    if (candidates.length == 1 && candidates.first == settings.activeUrl) {
      return;
    }
    // The active endpoint is **not among the candidates**, deleted or
    // edited, so we adopt the result even if it equals the old one, or the
    // app stays pinned to an address that no longer exists.
    final activeIsStale = !candidates.contains(settings.activeUrl);
    // Nothing responds, so **we keep the active endpoint as it is**: the
    // network may be mid-switch, and clearing the URL empties the library
    // in
    // front of the user.
    if (_running) {
      _pending = true;
      return;
    }
    _running = true;
    try {
      final probe = await _ref
          .read(endpointResolverProvider)
          .resolveDetailed(
            localUrl: settings.localUrl,
            externalUrls: settings.externalUrls,
          );
      final best = probe.url;
      // A server switch is the most important diagnostic event in Super,
      // and it
      // was not being logged.
      if (best == null) {
        // **The reason is logged** (field report 2026-09-05): putting the
        // server behind Cloudflare Access stopped switching, and nothing in
        // the log distinguished "locked" from "unreachable", so the fault
        // looked causeless.
        final locked = probe.statuses.values
            .where((s) => s == MTEndpointStatus.unauthorized)
            .length;
        unawaited(
          _ref
              .read(loggerProvider)
              .log(
                locked > 0
                    ? 'no usable endpoint — $locked rejected credentials (401)'
                    : 'no usable endpoint — none reachable',
                tag: 'network',
              ),
        );
        return;
      }
      if (best == settings.activeUrl && !activeIsStale) return;
      lastAdopted = best;
      // **A fourth trigger, caught on the device:** editing the endpoint
      // list
      // fired no probe, so the app stayed pinned to an address that was no
      // longer registered at all.
      unawaited(
        _ref
            .read(loggerProvider)
            .log('server switched to $best', tag: 'network'),
      );
      await _ref.read(settingsProvider.notifier).adoptActiveUrl(best);
    } finally {
      _running = false;
      if (_pending) {
        _pending = false;
        schedule();
      }
    }
  }

  void dispose() {
    _timer?.cancel();
    _lifecycle?.dispose();
    unawaited(_sub?.cancel());
  }
}

/// It runs for the life of the app, watched from [SuperApp] rather than
/// from a screen.
final autoSwitchProvider = Provider<AutoSwitchService>((ref) {
  final service = AutoSwitchService(ref)..start();

  // **A fourth trigger, caught on the device:** editing the endpoint list
  // fired no probe, so the app stayed pinned to an address that was no
  // longer registered at all.
  ref.listen<(String, String, bool)>(
    settingsProvider.select(
      (s) => (s.localUrl, s.externalUrls.join('|'), s.autoSwitch),
    ),
    (_, _) => service.schedule(),
  );

  // **A fifth trigger:** a failed server call. Not every outage comes with
  // a network event; the server may be restarted, or the phone may move
  // between access points with no route to the LAN. The failure itself is
  // the only signal then.
  ref.listen(historyProvider, (_, next) {
    if (next.hasError) service.schedule();
  });

  ref.onDispose(service.dispose);
  return service;
});

/// **Seeding the endpoint list.** An older install, and the first-run
/// setup, write `server_url` alone, so the endpoint list stays empty and
/// automatic switching has no candidates: it looks enabled and switches
/// nothing. Here the configured URL is classified once: a private network
/// address becomes "local", anything else becomes the first external
/// endpoint.
Future<void> seedEndpointsFromActive(
  KeyValueStore store,
  PrefsMutex mutex,
  SuperSettings settings,
) async {
  final active = (settings.activeUrl ?? '').trim();
  if (active.isEmpty) return;
  if (settings.localUrl.trim().isNotEmpty || settings.externalUrls.isNotEmpty) {
    return;
  }
  await mutex.run(() async {
    if (isPrivateHostUrl(active)) {
      await store.setString('local_url', active);
    } else {
      await store.setStringList('external_urls', [active]);
    }
  });
}

/// Is this address on a local network? (`10.x`, `192.168.x`, `172.16-31.x`,
/// `127.x`, `*.local`, or a name with no dot.) Used only to classify the
/// configured URL.
bool isPrivateHostUrl(String url) {
  final host = Uri.tryParse(url)?.host ?? '';
  if (host.isEmpty) return false;
  if (host == 'localhost' || host.endsWith('.local')) return true;
  if (!host.contains('.')) return true;
  final octets = host.split('.');
  if (octets.length != 4) return false;
  final n = octets.map(int.tryParse).toList();
  if (n.any((v) => v == null || v < 0 || v > 255)) return false;
  return switch (n[0]!) {
    10 || 127 => true,
    192 => n[1] == 168,
    172 => n[1]! >= 16 && n[1]! <= 31,
    _ => false,
  };
}
