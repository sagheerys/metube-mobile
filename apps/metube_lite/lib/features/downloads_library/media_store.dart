import 'package:flutter/services.dart';

/// Registering a completed file in MediaStore so it appears in the phone's
/// gallery.
///
/// The channel is implemented in `MainActivity.kt` by calling
/// `MediaScannerConnection` from the Android framework directly (a
/// documented deviation from the abandoned `media_scanner` package). A
/// failure here **does not fail the download**: the file is on disk and the
/// library sees it, and its absence from the gallery is an annoyance rather
/// than a loss.
class MediaStoreScanner {
  const MediaStoreScanner([this.channel = _defaultChannel]);

  static const _defaultChannel = MethodChannel('metube_lite/media');
  final MethodChannel channel;

  /// Returns the gallery URI on success, or null when registration failed.
  Future<String?> scanFile(String path) async {
    try {
      return await channel.invokeMethod<String>('scanFile', {'path': path});
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
