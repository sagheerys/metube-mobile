import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mt_ui/mt_ui.dart' show MTPalette;

/// Download notifications: progress while pulling, completion whose tap
/// opens the app and highlights the item, and errors. A silent channel for
/// progress and another for the result, so the phone does not ring at every
/// percentage.
class DownloadNotifications {
  DownloadNotifications({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const progressChannelId = 'com.yasir.metubelite.progress';
  static const resultChannelId = 'com.yasir.metubelite.result';

  final FlutterLocalNotificationsPlugin _plugin;

  /// Called once at startup. [onOpenItem] carries the completed item's key
  /// for the app to highlight (`03-APP-FLOW.md` §1).
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

  /// Android 13+ requires an explicit permission; a refusal fails nothing.
  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  /// [percent] of null means an **indeterminate** bar, for a phase with no
  /// percentage: waiting in the queue, adding to the server, cleaning it
  /// up.
  /// The secondary text [body] says exactly where we are: "downloading on
  /// the server" is not "pulling to your device".
  Future<void> showProgress(
    int id, {
    required String title,
    required String channelName,
    required int? percent,
    String? body,
  }) => _plugin.show(
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
  }) => _plugin.show(
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
