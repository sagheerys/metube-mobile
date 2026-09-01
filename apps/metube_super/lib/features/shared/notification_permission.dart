import 'package:flutter/services.dart';

/// إذن الإشعارات لإشعار الوسائط (م-21) — أندرويد 13+ يشترط طلباً صريحاً،
/// وبدونه يُكتم الإشعار **بصمت** والصوت يعمل بالخلفية بلا أي تحكم ظاهر.
/// القناة الأصلية في `MainActivity.kt`؛ الرفض لا يُفشل التشغيل.
class NotificationPermission {
  const NotificationPermission(
      [this.channel =
          const MethodChannel('com.yasir.metubesuper/permissions')]);

  final MethodChannel channel;

  Future<void> request() async {
    try {
      await channel.invokeMethod<bool>('requestNotifications');
    } on PlatformException {
      // منصة بلا القناة (اختبارات/سطح مكتب) — لا شيء يُفعل.
    } on MissingPluginException {
      // نفس الحالة.
    }
  }
}
