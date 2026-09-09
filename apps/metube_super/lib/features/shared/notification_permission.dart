import 'package:flutter/services.dart';

/// The notification permission for the media notification: Android 13+
/// requires an explicit request, and without it the notification is
/// suppressed **silently** while audio plays in the background with no
/// visible control at all. The native channel is in `MainActivity.kt`, and
/// a refusal fails nothing.
class NotificationPermission {
  const NotificationPermission([
    this.channel = const MethodChannel('com.yasir.metubesuper/permissions'),
  ]);

  final MethodChannel channel;

  Future<void> request() async {
    try {
      await channel.invokeMethod<bool>('requestNotifications');
    } on PlatformException {
      // The same case.
    } on MissingPluginException {
      // The same case.
    }
  }
}
