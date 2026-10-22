import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../../di.dart';
import 'reception.dart';

/// The links already sent to the server, by any route: the clipboard bar,
/// the add sheet, a share, a playlist, a retry.
///
/// The clipboard keeps a link long after it was downloaded, so without
/// this the bar offered the same link again on every return to the app,
/// and again after a restart. Kept on disk for that reason, newest first,
/// capped at [limit] because the clipboard only ever holds one link and
/// anything older than a few dozen downloads is no longer on it.
class HandledLinks {
  HandledLinks({required this.store, required this.mutex});

  static const storageKey = 'clipboard_handled_links';
  static const limit = 50;

  final KeyValueStore store;
  final PrefsMutex mutex;

  final List<String> _links = [];

  /// Completes once the saved list is merged in. A link added before then
  /// is kept: it goes in front of the saved ones.
  late final Future<void> ready = _load();

  Future<void> _load() async {
    final saved = await store.getStringList(storageKey) ?? const [];
    _merge(saved);
  }

  void _merge(List<String> saved) {
    for (final link in saved) {
      if (!_links.contains(link)) _links.add(link);
    }
    if (_links.length > limit) _links.removeRange(limit, _links.length);
  }

  /// Matched loosely, as `/history` is: a shared YouTube link carries a
  /// tracking `si=` that the copied one may not.
  bool contains(String url) => _links.any((l) => UrlKit.urlsMatch(l, url));

  /// Takes effect in memory at once, so a clipboard read already in flight
  /// sees it; the write to disk follows.
  Future<void> add(String url) {
    if (url.isEmpty) return Future.value();
    _links
      ..remove(url)
      ..insert(0, url);
    if (_links.length > limit) _links.removeLast();
    return mutex.run(() async {
      await ready;
      _merge(await store.getStringList(storageKey) ?? const []);
      await store.setStringList(storageKey, List.of(_links));
    });
  }
}

final handledLinksProvider = Provider(
  (ref) => HandledLinks(
    store: ref.watch(keyValueStoreProvider),
    mutex: ref.watch(prefsMutexProvider),
  ),
);

/// Records every link [engine] is given, and folds the clipboard bar away
/// when it is offering that link. Called by the provider that builds the
/// engine, so it lives and dies with it.
void noteSubmittedLinks(Ref ref, DownloadEngine engine) {
  final handled = ref.read(handledLinksProvider);
  final seen = <String>{};
  final subscription = engine.updates.listen((task) {
    // Every progress step is an update; only the first one per task is a
    // submission.
    if (!seen.add(task.id)) return;
    unawaited(handled.add(task.inputUrl));
    final offered = ref.read(clipboardUrlProvider);
    if (offered != null && UrlKit.urlsMatch(offered, task.inputUrl)) {
      ref.read(clipboardUrlProvider.notifier).state = null;
    }
  });
  ref.onDispose(subscription.cancel);
}
