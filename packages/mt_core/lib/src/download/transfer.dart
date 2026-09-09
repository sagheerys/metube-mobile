import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;

import '../api/api_exceptions.dart';
import '../api/metube_api.dart';
import '../constants/mt_constants.dart';

/// Pulling with retries (§2.4): 3 attempts backing off 3s then 6s, for
/// Cloudflare interruptions, **deleting the partial file before every
/// attempt** and on cancellation or failure.
///
/// **Writing to `<savePath>.part` then renaming** (field report
/// 2026-09-02): Dio writes incrementally into the final file, and Lite's
/// library is built by **scanning the folder**, so a clip appeared in the
/// library half downloaded with its size flickering on every refresh. The
/// `.part` suffix is not a media extension, so the scan skips it.
class Transfer {
  Transfer({
    required this.api,
    this.retries = MTConstants.pullRetries,
    this.backoff = MTConstants.pullRetryBackoff,
  });

  /// The partial file suffix. It **must not be a media extension**, so the
  /// library scan (`isMediaFile`) skips it.
  static const partSuffix = '.part';

  final MeTubeApi api;
  final int retries;

  /// The waits between attempts, zeroed in tests.
  final List<Duration> backoff;

  /// Returns **the path actually used**, which may differ from [savePath]
  /// if that was taken. The caller indexes what comes back,
  /// not what it asked for.
  Future<String> pull({
    required String serverFilename,
    required String savePath,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final partPath = '$savePath$partSuffix';
    for (var attempt = 0; attempt < retries; attempt++) {
      await _deletePartial(partPath);
      try {
        await api.downloadTo(
          serverFilename,
          partPath,
          cancelToken: cancelToken,
          onProgress: (received, total) {
            if (onProgress != null && total > 0) {
              onProgress(received / total);
            }
          },
        );
        // The atomic move: only from here does the folder scan see it.
        final target = await _freeTarget(savePath);
        await File(partPath).rename(target);
        return target;
      } on CancelledException {
        await _deletePartial(partPath);
        rethrow;
      } on MTApiException {
        await _deletePartial(partPath);
        final isLastAttempt = attempt == retries - 1;
        if (isLastAttempt) rethrow;
        if (attempt < backoff.length) {
          await Future<void>.delayed(backoff[attempt]);
        }
        if (cancelToken?.isCancelled ?? false) {
          throw const CancelledException();
        }
      }
    }
    throw const NetworkException('pull exhausted');
  }

  /// **An unoccupied target.** The local filename carries an
  /// `HHmmss` stamp with no date (§2.4), so two identical titles in the
  /// same second, plausible in an audio batch, or at the same time on two
  /// different days, made `rename` **silently overwrite the older file**.
  /// The format stays as the contract documented it, and the rare collision
  /// is resolved with a numeric suffix.
  static Future<String> _freeTarget(String savePath) async {
    if (!await File(savePath).exists()) return savePath;
    final dot = savePath.lastIndexOf('.');
    final stem = dot > 0 ? savePath.substring(0, dot) : savePath;
    final ext = dot > 0 ? savePath.substring(dot) : '';
    for (var i = 2; i < 100; i++) {
      final candidate = '$stem($i)$ext';
      if (!await File(candidate).exists()) return candidate;
    }
    return savePath;
  }

  Future<void> _deletePartial(String savePath) async {
    try {
      final file = File(savePath);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // A temporarily locked file. The next attempt will write over it.
    }
  }
}
