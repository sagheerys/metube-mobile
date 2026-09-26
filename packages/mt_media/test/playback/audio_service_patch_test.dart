import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **Media buttons keep working after the audio service restarts.**
///
/// Found 2026-09-26 on a real phone: pause from the notification, the lock
/// screen and a media key did nothing while the in-app pause worked.
/// audio_service clears its command listener when its Android service is
/// destroyed and sets it again only when a Flutter engine attaches, so a
/// service recreated under a living engine dropped every command. The fix
/// is a patched copy of the plugin (third_party/audio_service/PATCHES.md).
///
/// The Java side cannot run here, so this pins the two things that make the
/// fix real: the workspace uses the patched copy, and the copy still carries
/// the patch. Updating the plugin without carrying the patch over fails here.
void main() {
  final root = Directory.current.parent.parent.path;
  String read(String path) => File('$root/$path').readAsStringSync();

  test('the workspace overrides audio_service with the patched copy', () {
    final pubspec = read('pubspec.yaml');
    expect(
      RegExp(
        r'dependency_overrides:\s*\n\s+audio_service:\s*\n\s+path: third_party/audio_service',
      ).hasMatch(pubspec),
      isTrue,
    );
  });

  test('every command guard fetches the listener again when it is gone', () {
    const javaDir =
        'third_party/audio_service/android/src/main/java/com/ryanheise/audioservice';
    final service = read('$javaDir/AudioService.java');
    final plugin = read('$javaDir/AudioServicePlugin.java');

    expect(service, contains('private static boolean hasListener()'));
    expect(
      service,
      contains(
        'if (listener == null) listener = AudioServicePlugin.currentListener();',
      ),
    );
    // The helper's own line is the only null check left; any other would be
    // a command dropped without asking the plugin first.
    expect('listener == null'.allMatches(service), hasLength(1));
    expect('!hasListener()'.allMatches(service).length, greaterThan(30));
    expect(
      plugin,
      contains('static AudioService.ServiceListener currentListener()'),
    );
  });
}
