import 'dart:io';

/// An update download failure. **A type of its own, separate from MeTube
/// server errors**: it comes from GitHub, not the server, and its message
/// never passes through the server error classifier.
class UpdateDownloadException implements Exception {
  const UpdateDownloadException(this.reason);

  /// A technical reason for the logs, never shown to the user as it is.
  final String reason;

  @override
  String toString() => 'UpdateDownloadException: $reason';
}

/// The download was cancelled by the user. Not an error to display.
class UpdateCancelledException implements Exception {
  const UpdateCancelledException();

  @override
  String toString() => 'UpdateCancelledException';
}

/// A simple cancellation flag: the interface raises it, and the loop reads
/// it between chunks.
class DownloadCancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// Downloads the update installer, **isolated from the client's Dio** like
/// the rest of the external network.
///
/// It writes to `<savePath>.part` and then renames: a half-downloaded file
/// handed to the package installer fails with an opaque "corrupt package"
/// message, and may linger in the cache suggesting an update is ready.
class ApkDownloader {
  ApkDownloader({HttpClient Function()? clientFactory})
    : _clientFactory = clientFactory ?? HttpClient.new;

  final HttpClient Function() _clientFactory;

  /// The first four bytes of any APK: an APK is a ZIP archive, and its
  /// signature is `PK\x03\x04`.
  static const List<int> zipMagic = [0x50, 0x4B, 0x03, 0x04];

  /// Returns the final path once the download has completed and been
  /// verified.
  ///
  /// [expectedSize] comes from the release data: a mismatch means a
  /// truncated file, from a network drop that ends the stream without an
  /// error.
  Future<String> download({
    required String url,
    required String savePath,
    int expectedSize = 0,
    void Function(double progress)? onProgress,
    DownloadCancelToken? cancel,
  }) async {
    final partPath = '$savePath.part';
    final part = File(partPath);
    if (part.existsSync()) await part.delete();
    await part.parent.create(recursive: true);

    final client = _clientFactory()
      ..connectionTimeout = const Duration(seconds: 20);
    IOSink? sink;
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.followRedirects = true;
      final response = await request.close();
      if (response.statusCode != 200) {
        throw UpdateDownloadException('HTTP ${response.statusCode}');
      }
      final total = response.contentLength > 0
          ? response.contentLength
          : expectedSize;
      sink = part.openWrite();
      var received = 0;
      var checkedMagic = false;
      await for (final chunk in response) {
        if (cancel?.isCancelled ?? false) {
          throw const UpdateCancelledException();
        }
        // **Signature check on the first chunk**: an HTML error page or a
        // login redirect arrives with status 200 and would be saved as
        // `.apk` without objection.
        if (!checkedMagic && chunk.length >= zipMagic.length) {
          checkedMagic = true;
          for (var i = 0; i < zipMagic.length; i++) {
            if (chunk[i] != zipMagic[i]) {
              throw const UpdateDownloadException('not an apk');
            }
          }
        }
        sink.add(chunk);
        received += chunk.length;
        if (onProgress != null && total > 0) {
          onProgress((received / total).clamp(0.0, 1.0));
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (!checkedMagic) {
        throw const UpdateDownloadException('empty download');
      }
      if (expectedSize > 0 && received != expectedSize) {
        throw const UpdateDownloadException('size mismatch');
      }
      final target = File(savePath);
      if (target.existsSync()) await target.delete();
      await part.rename(savePath);
      return savePath;
    } catch (_) {
      await sink?.close();
      if (part.existsSync()) await part.delete();
      rethrow;
    } finally {
      client.close(force: true);
    }
  }
}
