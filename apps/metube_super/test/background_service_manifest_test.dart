import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **Field report 2026-09-13:** "the download notification sits at zero in
/// the shade and only moves when I open the app again".
///
/// Measured on the emulator: Super had no foreground service, so seconds
/// after the user left the app Android froze it and not one `/history`
/// request went out for 90 seconds. The cure is Lite's own service, held
/// only while a task is active.
///
/// The code alone is not the cure: **without the manifest declaration the
/// system refuses to start the service and background mode stays silently
/// off** (the trap Lite documents). No widget test can see that, so this
/// guard reads the files the build reads.
void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml')
      .readAsStringSync();

  test('the flutter_background service is declared as a dataSync service', () {
    final service = RegExp(
      r'<service[^>]*IsolateHolderService[^>]*>',
      dotAll: true,
    ).stringMatch(manifest);
    expect(service, isNotNull, reason: 'بلا التصريح يرفض النظام تشغيل الخدمة');
    expect(service, contains('android:foregroundServiceType="dataSync"'));
  });

  test('the dataSync foreground service permission is requested', () {
    expect(
      manifest,
      contains('android.permission.FOREGROUND_SERVICE_DATA_SYNC'),
    );
  });

  test('flutter_background is a direct dependency of Super', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec,
      matches(RegExp(r'^\s+flutter_background:', multiLine: true)),
    );
  });
}
