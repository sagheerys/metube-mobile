import 'package:dio/dio.dart' show CancelToken;

import '../models/channel_subscription.dart';
import '../models/history_response.dart';
import '../models/quality.dart';
import '../models/server_version.dart';

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

  /// **What the server says it is** (§2.6), or null when it will not say.
  ///
  /// Outside the download pipeline: nothing depends on the answer, and
  /// every reason for not getting one — an older MeTube with no such
  /// endpoint, an image built by hand that reports `dev`, a deployment that
  /// does not expose it — is ordinary rather than an error. Hence null
  /// instead of a throw: "unknown" is a state the interface shows, not a
  /// failure it reports.
  Future<ServerVersion?> fetchVersion({Duration? timeout});

  /// **Does the file actually exist on the server right now?** One byte,
  /// short timeout.
  ///
  /// A record in `/history` does not mean a file on disk: a single dead
  /// item was enough to freeze the entire thumbnail probe queue
  /// (2026-09-07).
  Future<bool> fileExists(String serverFilename, {Duration? timeout});

  /// **The channels the server watches** (§2.7), or null when this server
  /// has no such endpoint.
  ///
  /// Null is not an empty list: an older MeTube answers 404, and the
  /// difference between "no subscriptions yet" and "this server cannot do
  /// subscriptions" is the difference between an empty screen and no
  /// screen at all.
  Future<List<ChannelSubscription>?> fetchSubscriptions({Duration? timeout});

  /// Starts watching [url]. The quality rule of [add] applies here too, so
  /// a numeric quality cannot escape to a non-YouTube channel.
  ///
  /// **Only videos published after this call are downloaded** — the server
  /// marks the existing catalogue as seen (§2.7).
  ///
  /// Returns the row the server created, whose `name` is the channel title
  /// it resolved, or null when the answer did not carry one.
  Future<ChannelSubscription?> subscribe(
    String url,
    Quality quality, {
    required int checkIntervalMinutes,
    bool compatibleVideo,
    String? titleRegex,
  });

  /// Changes one subscription. Every argument left null is left alone;
  /// [clearTitleRegex] is how a filter is removed, since null means "no
  /// change".
  Future<void> updateSubscription(
    String id, {
    String? name,
    bool? enabled,
    int? checkIntervalMinutes,
    String? titleRegex,
    bool clearTitleRegex,
  });

  Future<void> deleteSubscriptions(List<String> ids);

  /// **Does the server hold a cookies file** (§2.8), or null when it is
  /// too old to say. Null is "unknown", not "no".
  Future<bool?> hasCookies({Duration? timeout});

  /// Uploads a Netscape cookies file. [bytes] is the file verbatim;
  /// [filename] is only what the multipart part is labelled with.
  ///
  /// The server caps it at 1MB and answers 400 above that, so the caller
  /// is told before the wire is used.
  Future<void> uploadCookies(List<int> bytes, {String filename});

  /// Removes the **uploaded** cookies. A server whose cookies come from
  /// `YTDL_OPTIONS` instead answers 400 saying so, which is passed on
  /// rather than swallowed: only the operator can undo that one.
  Future<void> deleteCookies();

  /// Checks now instead of waiting for the interval. Null [ids] means
  /// every enabled subscription.
  Future<void> checkSubscriptions({List<String>? ids});

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
