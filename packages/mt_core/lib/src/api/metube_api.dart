import 'package:dio/dio.dart' show CancelToken;

import '../models/history_response.dart';
import '../models/quality.dart';

/// The abstract MeTube server contract. [MeTubeApiClient] is the only
/// production implementation (rule 1); the interface exists so the engine
/// tests can fake a server.
abstract interface class MeTubeApi {
  Future<void> testConnection({Duration? timeout});
  Future<HistoryResponse> fetchHistory();

  /// [compatibleVideo] asks for **H.264/AAC in mp4** instead of letting the
  /// server choose (§2.2). It is never sent with `audio`. See the
  /// implementation for the measured reason.
  Future<void> add(String url, Quality quality, {bool compatibleVideo});
  Future<void> delete(List<String> canonicalUrls, {String where});
  String downloadUrl(String serverFilename);

  /// **Does the file actually exist on the server right now?** One byte,
  /// short timeout.
  ///
  /// A record in `/history` does not mean a file on disk: a single dead
  /// item was enough to freeze the entire thumbnail probe queue
  /// (2026-09-07).
  Future<bool> fileExists(String serverFilename, {Duration? timeout});

  /// Pulls a file to a local path with live progress and cancellation. One
  /// attempt, no retry; the retry logic lives in `Transfer`.
  Future<void> downloadTo(
    String serverFilename,
    String savePath, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  });

  Map<String, String> get streamingHeaders;
}
