import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mt_ui/mt_ui.dart' show MTPalette;

/// م-9: إشعارات التحميل — تقدم أثناء السحب، اكتمال (نقرته تفتح التطبيق
/// وتُبرز العنصر)، وخطأ. قناة صامتة للتقدم وأخرى للنتيجة كي لا يرن
/// الهاتف مع كل نسبة.
class DownloadNotifications {
  DownloadNotifications({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const progressChannelId = 'com.yasir.metubelite.progress';
  static const resultChannelId = 'com.yasir.metubelite.result';

  final FlutterLocalNotificationsPlugin _plugin;

  /// يُستدعى مرة عند الإقلاع. [onOpenItem] يحمل مفتاح العنصر المكتمل
  /// ليُبرزه التطبيق (`03-APP-FLOW.md` §1).
  Future<void> init({void Function(String itemKey)? onOpenItem}) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) onOpenItem?.call(payload);
      },
    );
  }

  /// أندرويد 13+ يشترط إذناً صريحاً — الرفض لا يُفشل شيئاً.
  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// [percent] = null ⇒ شريط **غير محدد** (طور بلا نسبة: الانتظار في
  /// الطابور، الإضافة للسيرفر، تنظيفه). النص الثانوي [body] يقول أين
  /// وصلنا بالضبط — «يحمّل على السيرفر» ليس كـ«يسحب إلى جهازك».
  Future<void> showProgress(
    int id, {
    required String title,
    required String channelName,
    required int? percent,
    String? body,
  }) =>
      _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            progressChannelId,
            channelName,
            importance: Importance.low,
            priority: Priority.low,
            onlyAlertOnce: true,
            showProgress: true,
            indeterminate: percent == null,
            maxProgress: 100,
            progress: (percent ?? 0).clamp(0, 100),
            ongoing: true,
            playSound: false,
          ),
        ),
      );

  Future<void> showResult(
    int id, {
    required String title,
    required String body,
    required String channelName,
    String? payload,
    bool isError = false,
  }) =>
      _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            resultChannelId,
            channelName,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            color: isError ? MTPalette.notificationError : null,
          ),
        ),
        payload: payload,
      );

  Future<void> cancel(int id) => _plugin.cancel(id: id);
}
