import 'package:flutter/services.dart';

/// م-10: تسجيل الملف المكتمل في MediaStore ليظهر في معرض الهاتف.
///
/// القناة منفَّذة في `MainActivity.kt` بنداء `MediaScannerConnection`
/// من إطار أندرويد مباشرة (انحراف موثق عن حزمة `media_scanner` المهجورة).
/// الفشل هنا **لا يُفشل التحميل** — الملف موجود على القرص والمكتبة تراه؛
/// غياب المعرض إزعاج لا خسارة.
class MediaStoreScanner {
  const MediaStoreScanner([this.channel = _defaultChannel]);

  static const _defaultChannel = MethodChannel('metube_lite/media');
  final MethodChannel channel;

  /// يرجع URI المعرض عند النجاح، أو null إن تعذّر التسجيل.
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
