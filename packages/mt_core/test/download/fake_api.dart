import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:mt_core/mt_core.dart';

/// A programmable fake MeTube server for the engine and transfer tests.
class FakeApi implements MeTubeApi {
  FakeApi({this.historyScript = const []});

  /// `/history` responses in order; the last one repeats once they run out.
  List<HistoryResponse> historyScript;
  int historyCalls = 0;
  void Function(int call)? onHistoryFetch;

  final List<(String url, Quality quality)> adds = [];
  Future<void> Function()? beforeAdd;

  final List<(List<String> ids, String where)> deletes = [];

  /// Thrown instead of performing the delete, to test a failed cleanup
  /// after a successful pull.
  MTApiException? deleteError;

  int downloadCalls = 0;

  /// How many progress ticks the fake pull broadcasts (0 means just two).
  int fineProgressTicks = 0;
  int failDownloadsBeforeSuccess = 0;
  bool hangDownloadUntilCancel = false;
  String downloadContent = 'MEDIA-DATA';

  @override
  Future<void> testConnection({Duration? timeout}) async {}

  /// Makes the **first** `/history` read fail, which is the reading taken
  /// before the add: "the server could not be read" must not be read as
  /// "the server is empty".
  bool failHistoryOnce = false;

  @override
  Future<HistoryResponse> fetchHistory() async {
    if (failHistoryOnce) {
      failHistoryOnce = false;
      throw const NetworkException('history unreachable');
    }
    final call = historyCalls++;
    onHistoryFetch?.call(call);
    if (historyScript.isEmpty) return const HistoryResponse();
    return historyScript[call < historyScript.length
        ? call
        : historyScript.length - 1];
  }

  /// The last value received for `compatibleVideo`, asserted by the engine
  /// test.
  bool? lastCompatibleVideo;

  @override
  Future<void> add(
    String url,
    Quality quality, {
    bool compatibleVideo = false,
  }) async {
    lastCompatibleVideo = compatibleVideo;
    await beforeAdd?.call();
    adds.add((url, quality.applyRule(url)));
  }

  @override
  Future<void> delete(
    List<String> canonicalUrls, {
    String where = 'done',
  }) async {
    deletes.add((canonicalUrls, where));
    if (deleteError != null) throw deleteError!;
  }

  /// Names claimed to be missing on the server, to test the probe guard.
  final Set<String> missingFiles = {};

  @override
  Future<bool> fileExists(String serverFilename, {Duration? timeout}) async =>
      !missingFiles.contains(serverFilename);

  /// What `/version` answers; null is the ordinary case of a server that
  /// will not say (§2.6).
  ServerVersion? version;

  @override
  Future<ServerVersion?> fetchVersion({Duration? timeout}) async => version;

  /// The subscriptions this fake server watches. **Null is the older
  /// MeTube that has no such endpoint** (§2.7), and it is the default: the
  /// download engine knows nothing about subscriptions, so every test that
  /// does not care gets the server that cannot do them.
  List<ChannelSubscription>? subscriptions;

  final List<String> subscribeCalls = [];
  final List<String> checkedSubscriptions = [];

  @override
  Future<List<ChannelSubscription>?> fetchSubscriptions({
    Duration? timeout,
  }) async => subscriptions;

  @override
  Future<ChannelSubscription?> subscribe(
    String url,
    Quality quality, {
    required int checkIntervalMinutes,
    bool compatibleVideo = false,
    String? titleRegex,
  }) async {
    subscribeCalls.add(url);
    return null;
  }

  @override
  Future<void> updateSubscription(
    String id, {
    String? name,
    bool? enabled,
    int? checkIntervalMinutes,
    String? titleRegex,
    bool clearTitleRegex = false,
  }) async {}

  @override
  Future<void> deleteSubscriptions(List<String> ids) async {
    subscriptions?.removeWhere((sub) => ids.contains(sub.id));
  }

  @override
  Future<void> checkSubscriptions({List<String>? ids}) async {
    checkedSubscriptions.addAll(ids ?? const ['*']);
  }

  /// Null is the older MeTube that cannot say (§2.8).
  bool? cookiesPresent;
  final List<int> uploadedCookies = [];

  @override
  Future<bool?> hasCookies({Duration? timeout}) async => cookiesPresent;

  @override
  Future<void> uploadCookies(
    List<int> bytes, {
    String filename = 'cookies.txt',
  }) async {
    uploadedCookies
      ..clear()
      ..addAll(bytes);
    cookiesPresent = true;
  }

  @override
  Future<void> deleteCookies() async {
    uploadedCookies.clear();
    cookiesPresent = false;
  }

  @override
  String downloadUrl(String serverFilename) {
    if (!UrlKit.isSafeServerFilename(serverFilename)) {
      throw const UnsafeFilenameException();
    }
    return 'https://fake/download/$serverFilename';
  }

  @override
  Future<void> downloadTo(
    String serverFilename,
    String savePath, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    downloadCalls++;
    if (cancelToken?.isCancelled ?? false) {
      throw const CancelledException();
    }
    if (hangDownloadUntilCancel) {
      await File(savePath).writeAsString('partial');
      await cancelToken?.whenCancel;
      throw const CancelledException();
    }
    if (downloadCalls <= failDownloadsBeforeSuccess) {
      await File(savePath).writeAsString('partial');
      throw const NetworkException('cloudflare hiccup');
    }
    // **Fine-grained ticks, as Dio really behaves**: `onReceiveProgress` is
    // called on every chunk received, not twice. The broadcast throttling
    // guard uses this.
    if (fineProgressTicks > 0) {
      for (var i = 1; i <= fineProgressTicks; i++) {
        onProgress?.call(i, fineProgressTicks);
      }
      await File(savePath).writeAsString(downloadContent);
      return;
    }
    onProgress?.call(50, 100);
    await File(savePath).writeAsString(downloadContent);
    onProgress?.call(100, 100);
  }

  @override
  Map<String, String> get streamingHeaders => const {};
}

/// History items ready for the scenarios.
HistoryResponse historyWith({
  List<Map<String, dynamic>> done = const [],
  List<Map<String, dynamic>> queue = const [],
}) => HistoryResponse.fromJson({'done': done, 'queue': queue});
