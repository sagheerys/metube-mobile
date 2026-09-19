import 'dart:convert';

import '../models/quality.dart';
import '../storage/key_value_store.dart';

/// **A download the app promised to finish, written down before it starts.**
///
/// Tasks live in the engine's memory, and the engine dies with the process:
/// killed from the recents list, stopped by the battery manager — Samsung's
/// Freecess was measured trying twice in one session — or simply restarted.
/// The server, meanwhile, carries on and finishes the file. Nobody is left
/// who knows to pull it and clean up, so **Lite's whole promise, "the
/// server cleans itself", quietly fails** and the file stays there forever.
///
/// The same record also covers the two failures that need no crash: a
/// single network blip during polling, and a download that outlives the
/// polling ceiling. In all three the server finishes and the app has
/// stopped watching.
///
/// Deliberately small: enough to find the item in `/history` again and to
/// know what was ours. Progress, titles and thumbnails are not kept — they
/// are re-read from the server, and a stale copy would only mislead.
class PendingDownload {
  const PendingDownload({
    required this.id,
    required this.url,
    required this.quality,
    required this.createdAt,
    this.before = const {},
    this.canonicalUrl,
    this.serverFilename,
    this.localPath,
  });

  /// The engine's task id, so a live task and its record stay one thing.
  final String id;

  /// The URL **as sent to the server**, after short-link resolution: it is
  /// what `/history` can be matched against.
  final String url;

  final Quality quality;
  final DateTime createdAt;

  /// The `/history` fingerprints from **before** the add.
  ///
  /// Carried across the restart for the same reason the engine takes it in
  /// the first place: without it, an older item for the same URL — a
  /// previous failure, a copy at another quality — is mistaken for this
  /// download, and the app pulls or deletes something it never asked for.
  final Set<String> before;

  /// Known once polling has seen the finished item; null before that.
  final String? canonicalUrl;
  final String? serverFilename;

  /// **Where the pull put the file**, written the moment the pull ends.
  ///
  /// The delete that follows the pull is a request of its own, and the
  /// process can die during it — or the server can refuse it. Either way
  /// the file is already on the phone, and the sweep must **only clean
  /// the server**, not pull a second copy under a new name.
  final String? localPath;

  PendingDownload copyWith({
    Set<String>? before,
    String? canonicalUrl,
    String? serverFilename,
    String? localPath,
  }) => PendingDownload(
    id: id,
    url: url,
    quality: quality,
    createdAt: createdAt,
    before: before ?? this.before,
    canonicalUrl: canonicalUrl ?? this.canonicalUrl,
    serverFilename: serverFilename ?? this.serverFilename,
    localPath: localPath ?? this.localPath,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'quality': quality.wire,
    'createdAt': createdAt.toIso8601String(),
    'before': before.toList(),
    if (canonicalUrl != null) 'canonicalUrl': canonicalUrl,
    if (serverFilename != null) 'serverFilename': serverFilename,
    if (localPath != null) 'localPath': localPath,
  };

  /// Returns null for anything unreadable: a record written by a future
  /// version, or one damaged by a half-finished write. A record is a
  /// convenience, never a reason to fail at startup.
  static PendingDownload? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final url = raw['url'];
    if (id is! String || id.isEmpty || url is! String || url.isEmpty) {
      return null;
    }
    final created = DateTime.tryParse('${raw['createdAt']}');
    if (created == null) return null;
    return PendingDownload(
      id: id,
      url: url,
      quality: Quality.fromWire('${raw['quality']}'),
      createdAt: created,
      before: {
        for (final item in (raw['before'] is List ? raw['before'] as List : []))
          '$item',
      },
      canonicalUrl: raw['canonicalUrl'] is String
          ? raw['canonicalUrl'] as String
          : null,
      serverFilename: raw['serverFilename'] is String
          ? raw['serverFilename'] as String
          : null,
      localPath: raw['localPath'] is String ? raw['localPath'] as String : null,
    );
  }
}

/// The records, in SharedPreferences under one key (§5.1).
///
/// One key holding a list rather than a key per download: the set is small,
/// it is read whole at startup and written whole on every change, and a
/// scattered set of keys is what leaves orphans behind when a write is
/// interrupted.
class PendingDownloadsStore {
  PendingDownloadsStore({
    required this.store,
    required this.mutex,
    this.maxAge = const Duration(days: 7),
  });

  static const String prefsKey = 'pending_downloads';

  final KeyValueStore store;
  final PrefsMutex mutex;

  /// **How long a record is worth acting on.** A week covers a phone left
  /// off over a holiday; beyond that the server has almost certainly been
  /// tidied by hand, and pulling a file somebody forgot they asked for is
  /// a surprise, not a service.
  final Duration maxAge;

  Future<List<PendingDownload>> readAll() => _readUnlocked();

  /// Adds or replaces one record, under the lock (rule 3).
  Future<void> put(PendingDownload pending) => mutex.run(() async {
    final all = await _readUnlocked();
    all
      ..removeWhere((p) => p.id == pending.id)
      ..add(pending);
    await _writeUnlocked(all);
  });

  Future<void> remove(String id) => mutex.run(() async {
    final all = await _readUnlocked()
      ..removeWhere((p) => p.id == id);
    await _writeUnlocked(all);
  });

  Future<void> clear() => mutex.run(() => store.remove(prefsKey));

  /// **Expired records are dropped on every read, including the one
  /// before a write**: a `put` or `remove` rewrites what it read, so a
  /// filter applied only when sweeping would carry a stale record forever.
  Future<List<PendingDownload>> _readUnlocked() async {
    final raw = await store.getString(prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = json.decode(raw);
      if (decoded is! List) return [];
      final cutoff = DateTime.now().subtract(maxAge);
      return [
        for (final entry in decoded)
          if (PendingDownload.fromJson(entry) case final p?)
            if (p.createdAt.isAfter(cutoff)) p,
      ];
    } on FormatException {
      return [];
    }
  }

  Future<void> _writeUnlocked(List<PendingDownload> all) async {
    if (all.isEmpty) return store.remove(prefsKey);
    await store.setString(
      prefsKey,
      json.encode([for (final p in all) p.toJson()]),
    );
  }
}
