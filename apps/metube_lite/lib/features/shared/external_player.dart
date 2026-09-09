import 'package:flutter/services.dart';

/// **"Open in an external player", for local files only** (decision
/// 2026-09-05).
///
/// The external player is handed a `content://` from `FileProvider` with a
/// temporary grant for that one file: no path, no server URL, and no
/// access to anything else.
///
/// **And a streaming URL is never handed over.** A Super server runs
/// without authentication, so its URL inside another app means open access
/// for anyone reading that app's logs. An item with no local copy is not
/// offered this option at all, rather than being offered it with a URL.
class ExternalPlayer {
  const ExternalPlayer([this.channel = _defaultChannel]);

  static const _defaultChannel = MethodChannel('metube_lite/media');
  final MethodChannel channel;

  /// `true` opened, `false` no player on the device, and a throw for a
  /// missing file.
  Future<bool> open(String path, {bool audio = false}) async {
    final ok = await channel.invokeMethod<bool>('openExternal', {
      'path': path,
      'mime': audio ? 'audio/*' : 'video/*',
    });
    return ok ?? false;
  }
}
