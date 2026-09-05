import 'package:flutter/services.dart';

/// **«فتح في مشغل خارجي» — للملفات المحلية وحدها** (قرار المالك
/// 2026-09-05).
///
/// يُسلَّم المشغلُ الخارجي `content://` من `FileProvider` بإذن مؤقت
/// للملف المطلوب وحده: لا مسار، ولا رابط سيرفر، ولا وصول لغيره.
///
/// **ولا يُسلَّم رابط بثّ أبداً.** سيرفر Super بلا استيثاق، فرابطه في
/// تطبيق آخر يعني وصولاً مفتوحاً لمن يقرأ سجلّ ذلك التطبيق — لذلك
/// العنصر الذي لا نسخة محلية له يُخفى عنه هذا الخيار بدل أن يُفتح
/// برابط.
class ExternalPlayer {
  const ExternalPlayer([this.channel = _defaultChannel]);

  static const _defaultChannel = MethodChannel('com.yasir.metubesuper/permissions');
  final MethodChannel channel;

  /// `true` فُتح · `false` لا مشغل على الجهاز · رمي عند ملف مفقود.
  Future<bool> open(String path, {bool audio = false}) async {
    final ok = await channel.invokeMethod<bool>('openExternal', {
      'path': path,
      'mime': audio ? 'audio/*' : 'video/*',
    });
    return ok ?? false;
  }
}
