import 'dart:io';

/// فشل تنزيل التحديث — **نوع مستقل عن أخطاء سيرفر MeTube**: مصدره
/// GitHub لا السيرفر، ورسالته لا تمرّ بمصنّف أخطاء السيرفر.
class UpdateDownloadException implements Exception {
  const UpdateDownloadException(this.reason);

  /// سبب تقني للسجلات — لا يُعرض للمستخدم كما هو.
  final String reason;

  @override
  String toString() => 'UpdateDownloadException: $reason';
}

/// أُلغي التنزيل بطلب المستخدم — ليس خطأً يُعرض.
class UpdateCancelledException implements Exception {
  const UpdateCancelledException();

  @override
  String toString() => 'UpdateCancelledException';
}

/// راية إلغاء بسيطة — الواجهة ترفعها، والحلقة تقرؤها بين القطع.
class DownloadCancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// تنزيل ملف تثبيت التحديث (م-66) — **معزول عن Dio العميل** كبقية
/// الشبكة الخارجية.
///
/// يكتب إلى `<savePath>.part` ثم يعيد التسمية: ملف نصف منزَّل يُسلَّم
/// لمثبّت الحزم يفشل برسالة «حزمة تالفة» مبهمة، وقد يبقى مخلَّفاً في
/// الكاش يوهم أن التحديث جاهز.
class ApkDownloader {
  ApkDownloader({HttpClient Function()? clientFactory})
      : _clientFactory = clientFactory ?? HttpClient.new;

  final HttpClient Function() _clientFactory;

  /// أول أربع بايتات لأي ملف APK — APK حزمة ZIP، وتوقيعها `PK\x03\x04`.
  static const List<int> zipMagic = [0x50, 0x4B, 0x03, 0x04];

  /// يعيد المسار النهائي بعد اكتمال التنزيل والتحقق.
  ///
  /// [expectedSize] من بيانات الإصدار: عدم تطابقه يعني ملفاً مبتوراً
  /// (انقطاع شبكة يُنهي التدفق بلا خطأ).
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
        // **التحقق من التوقيع على أول قطعة**: صفحة خطأ HTML أو تحويلة
        // تسجيل دخول تصل بحالة 200 وتُحفَظ باسم `.apk` بلا اعتراض.
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
