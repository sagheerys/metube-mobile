import 'dart:convert';

import 'package:mt_core/mt_core.dart';

import '../models/playlist_item.dart';

/// لقطة جلسة الصوت المحفوظة (م-21: استعادة القائمة بعد إعادة التشغيل).
class AudioSessionSnapshot {
  const AudioSessionSnapshot({
    required this.items,
    required this.index,
    this.position = Duration.zero,
    this.playlistId,
  });

  final List<PlaylistItem> items;
  final int index;
  final Duration position;

  /// معرف القائمة المحفوظة التي جاءت منها الجلسة (إن وُجدت).
  final String? playlistId;

  bool get isEmpty => items.isEmpty;

  Map<String, dynamic> toJson() => {
        'items': items.map((i) => i.toJson()).toList(),
        'index': index,
        'positionMs': position.inMilliseconds,
        if (playlistId != null) 'playlistId': playlistId,
      };
}

/// تخزين `audio_state` (§5.1) — يُكتب دورياً وعند كل تغيير عنصر،
/// ويُقرأ عند الإقلاع لإحياء المشغل المصغر بلا تشغيل تلقائي.
class AudioStateStore {
  AudioStateStore({required this.store, required this.mutex});

  final KeyValueStore store;
  final PrefsMutex mutex;

  static const String key = 'audio_state';

  Future<AudioSessionSnapshot?> read() async {
    final raw = await store.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return null;
      final rawItems = decoded['items'];
      if (rawItems is! List) return null;
      final items = <PlaylistItem>[];
      for (final entry in rawItems) {
        if (entry is Map) {
          final item =
              PlaylistItem.fromJson(Map<String, dynamic>.from(entry));
          if (item != null) items.add(item);
        }
      }
      if (items.isEmpty) return null;
      final index = decoded['index'];
      final ms = decoded['positionMs'];
      return AudioSessionSnapshot(
        items: items,
        index: index is num ? index.toInt().clamp(0, items.length - 1) : 0,
        position:
            Duration(milliseconds: ms is num ? ms.toInt().clamp(0, 1 << 40) : 0),
        playlistId: decoded['playlistId']?.toString(),
      );
    } on FormatException {
      return null; // حالة تالفة ⇒ تُتجاهل بصمت ولا تمنع الإقلاع.
    }
  }

  Future<void> write(AudioSessionSnapshot snapshot) => mutex.run(
        () => store.setString(key, json.encode(snapshot.toJson())),
      );

  /// يُمسح عند `stop()` — وإلا عاد «المشغل الشبح» بعد إعادة التشغيل.
  Future<void> clear() => mutex.run(() => store.remove(key));
}
