import 'package:flutter/services.dart';

/// جسر التثبيت الأصلي (م-66) — الطرف المقابل `UpdateInstaller.kt`.
///
/// **اسم القناة موحّد بين التطبيقين** فالملف متطابق حرفياً فيهما.
/// كل نداء فاشل-آمن: القناة غائبة في اختبارات الودجات وفي أي منصة
/// غير أندرويد، وغيابها يجب ألا يرمي في وجه المستخدم.
class UpdateChannel {
  const UpdateChannel();

  static const MethodChannel _channel = MethodChannel('mtf/update');

  /// هل يملك التطبيق إذن «تثبيت تطبيقات غير معروفة»؟
  Future<bool> canInstall() async {
    try {
      return await _channel.invokeMethod<bool>('canInstall') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// يفتح صفحة الإذن في إعدادات النظام لهذا التطبيق وحده.
  Future<void> openInstallSettings() async {
    try {
      await _channel.invokeMethod<bool>('openInstallSettings');
    } on PlatformException {
      // لا شيء نفعله: المستخدم سيُخبَر بالمسار نصياً في الحوار.
    } on MissingPluginException {
      // منصة بلا القناة.
    }
  }

  /// يسلّم ملف APK لمثبّت الحزم. `false` = لم تُفتح شاشة التثبيت.
  Future<bool> install(String path) async {
    try {
      return await _channel.invokeMethod<bool>('install', {'path': path}) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
