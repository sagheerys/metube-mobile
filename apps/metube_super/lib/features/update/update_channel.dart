import 'package:flutter/services.dart';

/// The native install bridge; the other end is `UpdateInstaller.kt`.
///
/// **The channel name is the same in both apps**, so this file is
/// identical in each. Every call is fail-safe: the channel is absent in
/// widget tests and on any platform other than Android, and its absence
/// must never throw in the user's face.
class UpdateChannel {
  const UpdateChannel();

  static const MethodChannel _channel = MethodChannel('mtf/update');

  /// Does the app hold the "install unknown apps" permission?
  Future<bool> canInstall() async {
    try {
      return await _channel.invokeMethod<bool>('canInstall') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Opens the permission page in the system settings for this app alone.
  Future<void> openInstallSettings() async {
    try {
      await _channel.invokeMethod<bool>('openInstallSettings');
    } on PlatformException {
      // Nothing to do: the dialog tells the user the path in words.
    } on MissingPluginException {
      // A platform without the channel.
    }
  }

  /// Hands the APK to the package installer. `false` means the install
  /// screen did not open.
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
