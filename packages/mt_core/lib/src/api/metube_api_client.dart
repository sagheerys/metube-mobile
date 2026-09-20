import 'dart:convert';

import 'package:dio/dio.dart';

import '../constants/mt_constants.dart';
import '../models/channel_subscription.dart';
import '../models/history_response.dart';
import '../models/quality.dart';
import '../models/server_version.dart';
import '../urls/playlist_detector.dart';
import '../urls/url_kit.dart';
import 'api_exceptions.dart';
import 'metube_api.dart';

/// Connection settings for a MeTube server. The URL is normalised by
/// stripping trailing slashes.
class ServerConfig {
  ServerConfig({required String baseUrl, this.username, this.password})
    : baseUrl = normalizeBaseUrl(baseUrl);

  final String baseUrl;
  final String? username;
  final String? password;

  static String normalizeBaseUrl(String raw) =>
      raw.trim().replaceFirst(RegExp(r'/+$'), '');

  bool get hasCredentials =>
      (username?.isNotEmpty ?? false) || (password?.isNotEmpty ?? false);

  /// The `Authorization` header value, or null when there are no
  /// credentials.
  String? get basicAuthHeader => hasCredentials
      ? 'Basic ${base64Encode(utf8.encode('${username ?? ''}:${password ?? ''}'))}'
      : null;

  @override
  bool operator ==(Object other) =>
      other is ServerConfig &&
      other.baseUrl == baseUrl &&
      other.username == username &&
      other.password == password;

  @override
  int get hashCode => Object.hash(baseUrl, username, password);
}

/// The one MeTube client. **All** network traffic towards the server goes
/// through here (rule 1). Every endpoint follows `docs/SERVER-API.md` §2
/// exactly.
class MeTubeApiClient implements MeTubeApi {
  MeTubeApiClient({required this.config, Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      connectTimeout: MTConstants.connectTimeout,
      receiveTimeout: MTConstants.receiveTimeout,
      // The response can arrive as text, so plain first and then a
      // defensive json.decode (§1).
      responseType: ResponseType.plain,
      validateStatus: (status) => status != null && status < 600,
    );
    final auth = config.basicAuthHeader;
    if (auth != null) {
      _dio.options.headers['Authorization'] = auth;
    }
  }

  final ServerConfig config;
  final Dio _dio;

  /// Streaming headers for the players (just_audio, video_player).
  @override
  Map<String, String> get streamingHeaders => {
    if (config.basicAuthHeader != null)
      'Authorization': config.basicAuthHeader!,
    'Connection': 'keep-alive',
  };

  /// §2.1: valid means 200 plus a JSON map carrying both `done` and
  /// `queue`.
  @override
  Future<void> testConnection({Duration? timeout}) async {
    final response = await _request(
      () => _dio.get<String>(
        '${config.baseUrl}/history',
        queryParameters: {'limit': 1},
        options: Options(
          receiveTimeout: timeout ?? MTConstants.testConnectionTimeout,
        ),
      ),
    );
    final decoded = _decode(response);
    if (!HistoryResponse.looksLikeMeTube(decoded)) {
      throw const NotMeTubeServerException();
    }
  }

  /// §2.3: the full history used for polling.
  @override
  Future<HistoryResponse> fetchHistory() async {
    final response = await _request(
      () => _dio.get<String>('${config.baseUrl}/history'),
    );
    final decoded = _decode(response);
    if (!HistoryResponse.looksLikeMeTube(decoded)) {
      throw const NotMeTubeServerException();
    }
    return HistoryResponse.fromJson(Map<String, dynamic>.from(decoded as Map));
  }

  /// §2.6: what the server says it is, or **null for every reason it might
  /// not say**.
  ///
  /// Older MeTubes have no such endpoint (404), a proxy may answer with an
  /// HTML page, and an image built by hand reports `dev`. None of those is
  /// a fault worth a message: the status card shows "unknown" and the rest
  /// of the app never asks. So this swallows its errors rather than
  /// classifying them — the one place in the client that does, because it
  /// is the one call whose failure means nothing.
  @override
  Future<ServerVersion?> fetchVersion({Duration? timeout}) async {
    try {
      final response = await _request(
        () => _dio.get<String>(
          '${config.baseUrl}/version',
          options: Options(
            receiveTimeout: timeout ?? MTConstants.testConnectionTimeout,
          ),
        ),
      );
      return ServerVersion.fromJson(_decode(response));
    } on Object {
      return null;
    }
  }

  /// **The name of the compatibility preset defined on the server**
  /// (measured 2026-09-08).
  ///
  /// `codec:h264` alone is not enough for Facebook: MeTube's format chain
  /// has three steps and the middle one carries **no codec filter**:
  /// `bestvideo[h264]+ba`, then `bestvideo+ba`, then `best`. Facebook's
  /// separate formats are all av01, so the first step fails and the
  /// **second picks av1 at 1440x2560** before the third can reach `hd`,
  /// which is **h264 at 720x1280 and genuinely present** (verified with
  /// ffprobe). H.264 is available and skipped over.
  ///
  /// The cure is to skip the middle step, and that is a `format` we do not
  /// build here but the server does. So a preset is defined by name on the
  /// container and the app sends **only its name**: no free-form yt-dlp
  /// options, so `ALLOW_YTDL_OPTIONS_OVERRIDES` never has to be opened.
  static const compatPreset = 'compat_h264';

  /// §2.2: adding a link. **The quality rule is applied here**, so a
  /// numeric quality can never escape to a non-YouTube link whatever the
  /// caller does.
  ///
  /// **Playback compatibility ([compatibleVideo])**, from field report
  /// 2026-09-03: "YouTube clips in reels look torn and unclear". Measured
  /// on a real server: `quality:best` alone yields **VP9 or AV1 in webm**
  /// (av1 1920x1080, vp9 480x848), and hardware AV1 decoding is missing
  /// from most phones, so a software decoder takes over and falls behind
  /// the frames: a torn picture.
  ///
  /// `format:mp4` alone is **not enough** (measured: it produced av1 inside
  /// mp4).
  ///
  /// And `codec` on its own **is ignored unless `download_type` is sent
  /// with it**, measured twice: without it the record comes back
  /// `codec:auto` with an av1 file; with it, `codec:h264` and an **h264
  /// Main / aac LC** file. So all three go together or none do, which is
  /// exactly the set MeTube's own interface sends.
  ///
  /// **Never sent with `audio`**: `format:mp4` on an audio path changes the
  /// requested container. [compatPreset] covers what `codec` cannot.
  @override
  Future<void> add(
    String url,
    Quality quality, {
    bool compatibleVideo = false,
  }) async {
    final applied = quality.applyRule(url);
    // **`best` only**: the selector is fixed with no `[height<=…]`, so
    // sending it alongside a numeric quality swallows the height ceiling
    // and downloads 1080p for someone who asked for 720p.
    final withPreset = compatibleVideo && applied == Quality.best;
    try {
      await _postAdd(
        url,
        applied,
        compatibleVideo: compatibleVideo,
        preset: withPreset,
      );
    } on ServerErrorException {
      if (!withPreset) rethrow;
      // **A server that does not know this preset answers 400** — and an
      // open-source app runs on containers nobody configured. Retrying
      // without the preset restores yesterday's behaviour instead of
      // failing the download outright.
      await _postAdd(
        url,
        applied,
        compatibleVideo: compatibleVideo,
        preset: false,
      );
    }
  }

  Future<void> _postAdd(
    String url,
    Quality applied, {
    required bool compatibleVideo,
    required bool preset,
  }) async {
    final response = await _request(
      () => _dio.post<String>(
        '${config.baseUrl}/add',
        data: jsonEncode({
          ..._downloadOptions(
            url,
            applied,
            compatibleVideo: compatibleVideo,
            preset: preset,
          ),
          // **What we take for a single item stays single on the server**
          // (field report 2026-09-08). `PlaylistDetector` recognises
          // YouTube playlists and SoundCloud `/sets/` only; an artist page,
          // an `/albums` URL or a channel looks like one clip to it, and
          // yt-dlp expands it server-side into dozens. The damage is worse
          // in Lite: twenty download, one is pulled, and nineteen orphans
          // stay on the family server with nobody deleting them.
          //
          // Measured on a real server: a three-track album plus this limit
          // yielded one download.
          if (!PlaylistDetector.isPlaylist(url)) 'playlist_item_limit': 1,
        }),
        options: Options(contentType: 'application/json'),
      ),
    );
    _throwIfBodyError(_decode(response));
  }

  /// **The download options `/add` and `/subscribe` share** (§2.2).
  ///
  /// A subscription downloads with exactly the same rules as a one-off:
  /// anything else and the clips that arrive by themselves would be the
  /// AV1-in-webm that the compatibility work exists to prevent.
  Map<String, Object?> _downloadOptions(
    String url,
    Quality applied, {
    required bool compatibleVideo,
    required bool preset,
  }) => {
    'url': url,
    'quality': applied.wire,
    if (compatibleVideo && applied != Quality.audio) ...{
      'download_type': 'video',
      'format': 'mp4',
      'codec': 'h264',
    },
    if (preset) 'ytdl_options_presets': const [compatPreset],
  };

  /// §2.7: the channels this server watches, or **null when it cannot
  /// watch any** — an older MeTube has no such endpoint.
  ///
  /// Like [fetchVersion] this swallows its errors, and for the same
  /// reason: the answer decides whether a screen exists at all, and an
  /// app that shows a broken subscriptions screen to everyone running an
  /// older container is worse than one that shows none.
  @override
  Future<List<ChannelSubscription>?> fetchSubscriptions({
    Duration? timeout,
  }) async {
    try {
      final response = await _request(
        () => _dio.get<String>(
          '${config.baseUrl}/subscriptions',
          options: Options(
            receiveTimeout: timeout ?? MTConstants.testConnectionTimeout,
          ),
        ),
      );
      return ChannelSubscription.listFromJson(_decode(response));
    } on Object {
      return null;
    }
  }

  /// §2.7: start watching a channel.
  ///
  /// **`playlist_item_limit` is deliberately absent**, unlike [add]: there
  /// the limit stops a channel exploding into dozens of one-off
  /// downloads, but here the explosion is the point, and a limit would
  /// make a check that finds more new videos than the limit skip the rest
  /// **permanently** — they never enter `seen_ids`, so no later check
  /// finds them either.
  @override
  Future<ChannelSubscription?> subscribe(
    String url,
    Quality quality, {
    required int checkIntervalMinutes,
    bool compatibleVideo = false,
    String? titleRegex,
  }) async {
    final applied = quality.applyRule(url);
    final withPreset = compatibleVideo && applied == Quality.best;
    try {
      return await _postSubscribe(
        url,
        applied,
        checkIntervalMinutes: checkIntervalMinutes,
        compatibleVideo: compatibleVideo,
        preset: withPreset,
        titleRegex: titleRegex,
      );
    } on ServerErrorException {
      // The same retry as [add]: a container nobody configured answers 400
      // to a preset it has never heard of.
      if (!withPreset) rethrow;
      return _postSubscribe(
        url,
        applied,
        checkIntervalMinutes: checkIntervalMinutes,
        compatibleVideo: compatibleVideo,
        preset: false,
        titleRegex: titleRegex,
      );
    }
  }

  Future<ChannelSubscription?> _postSubscribe(
    String url,
    Quality applied, {
    required int checkIntervalMinutes,
    required bool compatibleVideo,
    required bool preset,
    String? titleRegex,
  }) async {
    final response = await _request(
      () => _dio.post<String>(
        '${config.baseUrl}/subscribe',
        data: jsonEncode({
          ..._downloadOptions(
            url,
            applied,
            compatibleVideo: compatibleVideo,
            preset: preset,
          ),
          'check_interval_minutes': checkIntervalMinutes,
          if (titleRegex != null && titleRegex.trim().isNotEmpty)
            'title_regex': titleRegex.trim(),
        }),
        options: Options(contentType: 'application/json'),
      ),
    );
    // **A duplicate URL comes back as 200 with an error body** — "This URL
    // is already subscribed" — so the body is read, as §2.2 requires.
    final decoded = _decode(response);
    _throwIfBodyError(decoded);
    // The server answers with the row it created, carrying the channel
    // title it resolved. Worth keeping: it is the only place that name is
    // known without asking for the whole list again.
    if (decoded is! Map) return null;
    return ChannelSubscription.fromJson(decoded['subscription']);
  }

  /// §2.7: change one subscription. The server ignores any field outside
  /// its own list, so only the six it accepts are ever sent.
  @override
  Future<void> updateSubscription(
    String id, {
    String? name,
    bool? enabled,
    int? checkIntervalMinutes,
    String? titleRegex,
    bool clearTitleRegex = false,
  }) async {
    final changes = <String, Object?>{
      'name': ?name,
      'enabled': ?enabled,
      'check_interval_minutes': ?checkIntervalMinutes,
      // **An empty string is how a filter is removed**, not null: the
      // server only reads keys that are present, so null would mean "leave
      // the old filter alone" and the user's deletion would be silently
      // ignored.
      if (clearTitleRegex)
        'title_regex': ''
      else if (titleRegex != null)
        'title_regex': titleRegex.trim(),
    };
    // Nothing to say is not a request worth making; the server answers 400
    // to an empty change set.
    if (changes.isEmpty) return;
    final response = await _request(
      () => _dio.post<String>(
        '${config.baseUrl}/subscriptions/update',
        data: jsonEncode({'id': id, ...changes}),
        options: Options(contentType: 'application/json'),
      ),
    );
    _throwIfBodyError(_decode(response));
  }

  /// §2.7: stop watching. **This throws away what the server had seen**,
  /// so the interface offers pausing first.
  @override
  Future<void> deleteSubscriptions(List<String> ids) async {
    if (ids.isEmpty) return;
    final response = await _request(
      () => _dio.post<String>(
        '${config.baseUrl}/subscriptions/delete',
        data: jsonEncode({'ids': ids}),
        options: Options(contentType: 'application/json'),
      ),
    );
    _throwIfBodyError(_decode(response));
  }

  /// §2.7: check now. The call returns as soon as the server accepts the
  /// request; what it finds arrives through `/history` like any other
  /// download.
  @override
  Future<void> checkSubscriptions({List<String>? ids}) async {
    final response = await _request(
      () => _dio.post<String>(
        '${config.baseUrl}/subscriptions/check',
        data: jsonEncode({'ids': ?ids}),
        options: Options(
          contentType: 'application/json',
          // A check walks every channel with yt-dlp, which is slower than
          // anything else in this client.
          receiveTimeout: MTConstants.downloadReceiveTimeout,
        ),
      ),
    );
    _throwIfBodyError(_decode(response));
  }

  /// §2.8: **does the server hold cookies at all**, or null when it
  /// cannot say.
  ///
  /// Null like [fetchVersion]: an older MeTube has no such endpoint, and
  /// the difference between "no cookies" and "this server cannot tell
  /// you" is the difference between offering a delete button and not.
  @override
  Future<bool?> hasCookies({Duration? timeout}) async {
    try {
      final response = await _request(
        () => _dio.get<String>(
          '${config.baseUrl}/cookie-status',
          options: Options(
            receiveTimeout: timeout ?? MTConstants.testConnectionTimeout,
          ),
        ),
      );
      final decoded = _decode(response);
      if (decoded is! Map) return null;
      final has = decoded['has_cookies'];
      return has is bool ? has : null;
    } on Object {
      return null;
    }
  }

  /// §2.8: the cookies file, as multipart under the name the server reads.
  ///
  /// **The 1MB ceiling is checked here** rather than left to the server:
  /// a cookies export can be large, and sending megabytes over a phone's
  /// connection to be told "too big" wastes the one thing the user has
  /// less of than patience.
  @override
  Future<void> uploadCookies(
    List<int> bytes, {
    String filename = 'cookies.txt',
  }) async {
    if (bytes.isEmpty) throw const ServerErrorException('empty cookies file');
    if (bytes.length > cookiesMaxBytes) {
      throw const CookiesTooLargeException();
    }
    final form = FormData.fromMap({
      // **The field must be called `cookies`**: the server reads the first
      // multipart part and rejects any other name outright.
      'cookies': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _request(
      () => _dio.post<String>('${config.baseUrl}/upload-cookies', data: form),
    );
    _throwIfBodyError(_decode(response));
  }

  /// The server's own ceiling, mirrored so the app can refuse first.
  static const cookiesMaxBytes = 1000000;

  /// §2.8: removing the uploaded cookies.
  @override
  Future<void> deleteCookies() async {
    final response = await _request(
      () => _dio.post<String>(
        '${config.baseUrl}/delete-cookies',
        data: jsonEncode(const <String, Object?>{}),
        options: Options(contentType: 'application/json'),
      ),
    );
    _throwIfBodyError(_decode(response));
  }

  /// §2.5: deletion uses the canonicalUrl that came from `/history`, and
  /// nothing else.
  @override
  Future<void> delete(
    List<String> canonicalUrls, {
    String where = 'done',
  }) async {
    final response = await _request(
      () => _dio.post<String>(
        '${config.baseUrl}/delete',
        data: jsonEncode({'ids': canonicalUrls, 'where': where}),
        options: Options(contentType: 'application/json'),
      ),
    );
    _throwIfBodyError(_decode(response));
  }

  /// §2.4: the pull and stream URL, with the **mandatory filename guard**
  /// inside the client.
  @override
  String downloadUrl(String serverFilename) {
    if (!UrlKit.isSafeServerFilename(serverFilename)) {
      throw const UnsafeFilenameException();
    }
    return '${config.baseUrl}/download/${Uri.encodeComponent(serverFilename)}';
  }

  /// **A one-byte existence check**, the cheapest possible question, on a
  /// timeout of our own.
  ///
  /// The reason is measured: handing a dead URL to `MediaMetadataRetriever`
  /// makes the Android platform retry **ten times with an 8s timeout**,
  /// over 80 seconds that freeze the entire probe queue. Refusing here
  /// takes a fraction of a second.
  @override
  Future<bool> fileExists(String serverFilename, {Duration? timeout}) async {
    final String url;
    try {
      url = downloadUrl(serverFilename);
    } on UnsafeFilenameException {
      return false;
    }
    try {
      final response = await _dio.get<dynamic>(
        url,
        options: Options(
          // A one-byte range: the server answers 206 without sending the
          // file.
          headers: const {'Range': 'bytes=0-0'},
          responseType: ResponseType.bytes,
          receiveTimeout: timeout ?? MTConstants.probeTimeout,
          sendTimeout: timeout ?? MTConstants.probeTimeout,
        ),
      );
      final status = response.statusCode ?? 0;
      return status == 200 || status == 206;
    } on DioException {
      return false;
    }
  }

  /// §2.4: the actual pull to a file. Never `responseType: bytes` with
  /// `dio.download` (trap §1). One attempt; retries live in `Transfer`.
  @override
  Future<void> downloadTo(
    String serverFilename,
    String savePath, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final url = downloadUrl(serverFilename);
    final Response<dynamic> response;
    try {
      response = await _dio.download(
        url,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: onProgress,
        options: Options(
          receiveTimeout: MTConstants.downloadReceiveTimeout,
          headers: {'Connection': 'keep-alive'},
        ),
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        throw const CancelledException();
      }
      throw NetworkException(e.message);
    }
    _throwIfDownloadRejected(response.statusCode ?? 0);
  }

  /// Runs the request, classifies transport errors, then classifies HTTP
  /// statuses.
  static void _throwIfDownloadRejected(int status) {
    if (status == 200 || status == 206) return;
    if (status == 401 || status == 403) {
      throw AuthFailureException('HTTP $status');
    }
    if (status == 404) throw const NoApiException();
    throw ServerErrorException('HTTP $status');
  }

  void close() => _dio.close(force: true);

  // Internals.

  /// Defensive JSON decoding: HTML or broken text means this is not a
  /// MeTube
  /// server.
  Future<Response<String>> _request(
    Future<Response<String>> Function() send,
  ) async {
    Response<String> response;
    try {
      response = await send();
    } on DioException catch (e) {
      throw NetworkException(e.message);
    }
    final status = response.statusCode ?? 0;
    if (status == 401 || status == 403) {
      throw AuthFailureException('HTTP $status');
    }
    if (status == 404) throw const NoApiException();
    if (status < 200 || status >= 300) {
      final message =
          _extractErrorText(_tryDecode(response.data)) ?? 'HTTP $status';
      _throwClassified(message);
    }
    return response;
  }

  /// Defensive JSON decoding: HTML or broken text means this is not a
  /// MeTube server.
  dynamic _decode(Response<String> response) {
    final decoded = _tryDecode(response.data);
    if (decoded == null) throw const NotMeTubeServerException();
    return decoded;
  }

  static dynamic _tryDecode(String? body) {
    if (body == null || body.trim().isEmpty) return null;
    try {
      return json.decode(body);
    } on FormatException {
      return null;
    }
  }

  /// Even with a 200 the server can return `{"status":"error","msg":...}`
  /// (§2.2).
  void _throwIfBodyError(dynamic decoded) {
    if (decoded is! Map) return;
    if (decoded['status']?.toString().toLowerCase() == 'error' ||
        decoded.containsKey('error')) {
      _throwClassified(_extractErrorText(decoded) ?? 'server error');
    }
  }

  /// The error from `error` or `msg`, whether it arrives as text or a map.
  static String? _extractErrorText(dynamic decoded) {
    if (decoded is! Map) return null;
    final raw = decoded['error'] ?? decoded['msg'] ?? decoded['message'];
    if (raw == null) return null;
    if (raw is Map) {
      return raw.values.map((v) => v.toString()).join(' — ');
    }
    final text = raw.toString().trim();
    return text.isEmpty ? null : text;
  }

  Never _throwClassified(String message) {
    if (UrlKit.isPlatformBlockedError(message)) {
      throw PlatformBlockedException(message);
    }
    throw ServerErrorException(message);
  }
}
