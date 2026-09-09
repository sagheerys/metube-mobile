import 'dart:convert';

import 'package:dio/dio.dart';

import '../constants/mt_constants.dart';
import '../models/history_response.dart';
import '../models/quality.dart';
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
/// through here (rule 1). The four endpoints plus testConnection follow
/// `05-DATA-SCHEMA.md` §2 exactly.
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
          'url': url,
          'quality': applied.wire,
          if (compatibleVideo && applied != Quality.audio) ...{
            'download_type': 'video',
            'format': 'mp4',
            'codec': 'h264',
          },
          if (preset) 'ytdl_options_presets': const [compatPreset],
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

  /// A one-byte range: the server answers 206 without sending the file.
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

  /// **The download status guard — critical defect ح-1 (2026-09-02).**
  ///
  /// `validateStatus` in [BaseOptions] applies to `dio.download` as well,
  /// and dio's download path **does not check the status afterwards**. So
  /// an error page (a 401 after a password change, a transient 502 from a
  /// reverse proxy) was streamed into `.part` and then promoted to a
  /// "successful" media file. In Lite the original is deleted from the
  /// server right after, so the file is lost at both ends. Checking here
  /// makes it a classified failure: `Transfer` wipes the partial, and the
  /// server-side delete never happens at all.
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

  /// Runs the request, classifies transport errors, then classifies HTTP
  /// statuses.
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
