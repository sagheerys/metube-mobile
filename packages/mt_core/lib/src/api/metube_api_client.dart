import 'dart:convert';

import 'package:dio/dio.dart';

import '../constants/mt_constants.dart';
import '../models/history_response.dart';
import '../models/quality.dart';
import '../urls/url_kit.dart';
import 'api_exceptions.dart';
import 'metube_api.dart';

/// إعدادات الاتصال بسيرفر MeTube — الرابط يُطبَّع بإزالة الشرطات الأخيرة.
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

  /// قيمة ترويسة `Authorization` أو null بلا اعتمادات.
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

/// عميل MeTube الوحيد — **كل** الشبكة نحو السيرفر من هنا (القاعدة 1).
/// النقاط الأربع + testConnection حسب `05-DATA-SCHEMA.md` §2 حرفياً.
class MeTubeApiClient implements MeTubeApi {
  MeTubeApiClient({required this.config, Dio? dio})
      : _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      connectTimeout: MTConstants.connectTimeout,
      receiveTimeout: MTConstants.receiveTimeout,
      // الاستجابة قد تصل نصاً ⇒ plain ثم json.decode دفاعي (§1).
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

  /// ترويسات البث للمشغلات (just_audio / video_player).
  @override
  Map<String, String> get streamingHeaders => {
        if (config.basicAuthHeader != null)
          'Authorization': config.basicAuthHeader!,
        'Connection': 'keep-alive',
      };

  /// §2.1 — صالح ⇔ 200 + JSON Map يحوي `done` و`queue` معاً.
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

  /// §2.3 — السجل الكامل للاستطلاع.
  @override
  Future<HistoryResponse> fetchHistory() async {
    final response = await _request(() => _dio.get<String>(
          '${config.baseUrl}/history',
        ));
    final decoded = _decode(response);
    if (!HistoryResponse.looksLikeMeTube(decoded)) {
      throw const NotMeTubeServerException();
    }
    return HistoryResponse.fromJson(Map<String, dynamic>.from(decoded as Map));
  }

  /// §2.2 — إضافة رابط. **قاعدة الجودة تُطبَّق هنا** فلا تفلت رقمية لغير
  /// YouTube مهما كان المنادي.
  ///
  /// **توافق التشغيل ([compatibleVideo])** — بلاغ المالك 2026-09-03
  /// «مقاطع اليوتيوب في الريلز تظهر مشوشة وغير واضحة». القياس على
  /// سيرفره الحقيقي: `quality:best` وحدها تعطي **VP9 أو AV1 في webm**
  /// (`av1 1920×1080`، `vp9 480×848`) — وفكّ AV1 عتاديّاً غائب عن أغلب
  /// الهواتف، فيتولاه فكٌّ برمجي يتخلف عن الإطارات: صورة ممزقة.
  ///
  /// و`format:mp4` وحدها **لا تكفي** (مقيس: أعطت av1 داخل mp4).
  ///
  /// **و`codec` وحده يُتجاهَل ما لم يُرسل `download_type` معه** — مقيس
  /// مرتين: بدونه يعود السجل بـ`codec:auto` وملف av1؛ ومعه بـ`codec:h264`
  /// وملف **h264 Main / aac LC**. لذلك تُرسل الثلاثة معاً أو لا شيء،
  /// وهي نفس الحقول التي ترسلها واجهة MeTube نفسها.
  ///
  /// **لا يُرسل مع `audio` أبداً**: `format:mp4` على مسار صوتي يغيّر
  /// وعاء الملف المطلوب.
  @override
  Future<void> add(
    String url,
    Quality quality, {
    bool compatibleVideo = false,
  }) async {
    final applied = quality.applyRule(url);
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
        }),
        options: Options(contentType: 'application/json'),
      ),
    );
    _throwIfBodyError(_decode(response));
  }

  /// §2.5 — الحذف بالـ canonicalUrl القادم من `/history` حصراً.
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

  /// §2.4 — رابط السحب/البث مع **حارس اسم الملف الإلزامي** داخل العميل.
  @override
  String downloadUrl(String serverFilename) {
    if (!UrlKit.isSafeServerFilename(serverFilename)) {
      throw const UnsafeFilenameException();
    }
    return '${config.baseUrl}/download/${Uri.encodeComponent(serverFilename)}';
  }

  /// §2.4 — السحب الفعلي إلى ملف. ⚠️ لا `responseType: bytes` مع
  /// `dio.download` (فخ §1). محاولة واحدة — الإعادة في `Transfer`.
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

  /// **حارس حالة التنزيل — العطل الحرج ح-1 (2026-09-02).**
  ///
  /// `validateStatus` في [BaseOptions] ينطبق على `dio.download` أيضاً،
  /// ومسار التنزيل في dio **لا يفحص الحالة بعده**: فكانت صفحة خطأ
  /// (401 بعد تغيير كلمة السر، 502 عابر من الوكيل العكسي) تُبثّ إلى
  /// `.part` ثم تُرقّى ملفَ وسائط «ناجحاً» — وفي Lite يُحذف بعدها الأصل
  /// من السيرفر، فيضيع الملف من الطرفين. الفحص هنا يجعلها فشلاً مصنفاً:
  /// `Transfer` يمسح الجزئي، والحذف من السيرفر لا يقع أصلاً.
  static void _throwIfDownloadRejected(int status) {
    if (status == 200 || status == 206) return;
    if (status == 401 || status == 403) {
      throw AuthFailureException('HTTP $status');
    }
    if (status == 404) throw const NoApiException();
    throw ServerErrorException('HTTP $status');
  }

  void close() => _dio.close(force: true);

  // ── الداخلية ──

  /// ينفّذ الطلب، يصنّف أخطاء النقل، ثم يصنّف حالات HTTP.
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

  /// فك JSON دفاعي — HTML أو نص مكسور ⇒ ليس سيرفر MeTube.
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

  /// حتى مع 200 قد يعيد السيرفر `{"status":"error","msg":...}` (§2.2).
  void _throwIfBodyError(dynamic decoded) {
    if (decoded is! Map) return;
    if (decoded['status']?.toString().toLowerCase() == 'error' ||
        decoded.containsKey('error')) {
      _throwClassified(_extractErrorText(decoded) ?? 'server error');
    }
  }

  /// الخطأ من `error` أو `msg` — نصاً كان أو Map.
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
