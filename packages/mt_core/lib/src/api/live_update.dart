import 'dart:convert';

import '../models/history_item.dart';

/// One item as the server reports it the moment it changes, from MeTube's
/// live channel, between two reads of `/history`.
///
/// [completed] is the server's own word that the item is done. An update
/// whose status reads "finished" is not that: yt-dlp finishes each stream
/// of a clip (video, audio, subtitles) on its own before merging them, and
/// each of those arrives as a finished update with a file name that is not
/// the clip's.
class MTLiveUpdate {
  const MTLiveUpdate(this.item, {required this.completed});

  final HistoryItem item;
  final bool completed;

  /// The update in one Socket.IO packet (`42["updated", …]`), or null for
  /// anything else. The item may come as an object or as a JSON string,
  /// which is how MeTube sends it. The event that carries the whole
  /// history on connecting is skipped before it is decoded: it is as large
  /// as `/history` itself.
  static MTLiveUpdate? fromPacket(String packet) {
    final completed = packet.startsWith('42["completed",');
    if (!completed && !packet.startsWith('42["updated",')) return null;
    try {
      final decoded = jsonDecode(packet.substring(2));
      if (decoded is! List || decoded.length < 2) return null;
      var data = decoded[1];
      if (data is String) data = jsonDecode(data);
      if (data is! Map<String, dynamic>) return null;
      return MTLiveUpdate(HistoryItem.fromJson(data), completed: completed);
    } on FormatException {
      return null;
    }
  }
}
