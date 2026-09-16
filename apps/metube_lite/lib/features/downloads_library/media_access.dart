import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'library_providers.dart';
import 'local_item.dart';

/// **Android does not grant a dangerous permission because the manifest
/// declares it.** Declaring `READ_MEDIA_VIDEO` only makes the permission
/// askable; until something asks, every read of the download folder fails
/// with `PathAccessException ... Permission denied, errno = 13`, which is
/// exactly what a phone with a fresh profile showed (field report,
/// Galaxy S22 Ultra, 2026-09-16): the library was an error screen, and the
/// only way out was the system settings, which most users never find.
enum MediaAccess {
  granted,

  /// Refused this time; Android will ask again next time.
  denied,

  /// Refused for good ("don't ask again"), so only the system settings
  /// screen can change it.
  blocked,
}

/// Thrown by the library scan when the folder cannot be read, so the screen
/// can offer the permission instead of printing an errno at the user.
class MediaAccessDeniedException implements Exception {
  const MediaAccessDeniedException();

  @override
  String toString() => 'MediaAccessDeniedException';
}

/// Can the download folder be read right now?
typedef FolderProbe = Future<bool> Function();

/// Asks for [permissions] and answers **whether Android said "never
/// again"** to any of them.
typedef PermissionAsker = Future<bool> Function(List<Permission> permissions);

/// Is this permission granted right now?
typedef PermissionCheck = Future<bool> Function(Permission permission);

/// Opens the app's page in the system settings.
typedef SettingsOpener = Future<bool> Function();

/// **The filesystem is the judge, not the permission API.** Android's
/// permission names differ by version (`READ_MEDIA_*` from 13, a single
/// storage permission before it) and a wrong guess fails silently, so the
/// gate asks and then simply tries the folder again.
Future<bool> probeMediaFolder([String path = liteMediaDir]) async {
  final dir = Directory(path);
  try {
    if (await dir.exists()) return true;
    // Creating it is the same proof, and the folder has to exist anyway
    // before the first download lands in it.
    await dir.create(recursive: true);
    return true;
  } on FileSystemException {
    return false;
  }
}

Future<bool> _requestAll(List<Permission> permissions) async {
  final statuses = await permissions.request();
  return statuses.values.any((status) => status.isPermanentlyDenied);
}

Future<bool> _permissionIsGranted(Permission permission) =>
    permission.isGranted;

/// **An empty folder is not the same as a hidden one.**
///
/// Measured on the owner's phone (Galaxy S22 Ultra, Android 16,
/// 2026-09-16): with the media permission revoked, the folder still opened
/// and still listed — and listed *nothing*, so 28 downloads became "no
/// downloads yet" with no error, no dialog and no way back. Silence is the
/// worst of the three outcomes, so an empty library with no permission is
/// reported as what it is.
void assertLibraryVisible({required bool isEmpty, required bool hasAccess}) {
  if (isEmpty && !hasAccess) throw const MediaAccessDeniedException();
}

/// Obtains access to the download folder, asking the user once per attempt.
class MediaAccessGate {
  MediaAccessGate({
    FolderProbe? probe,
    PermissionAsker? ask,
    PermissionCheck? isGranted,
    SettingsOpener? openSettings,
  }) : _probe = probe ?? probeMediaFolder,
       _ask = ask ?? _requestAll,
       _isGranted = isGranted ?? _permissionIsGranted,
       _openSettings = openSettings ?? openAppSettings;

  final FolderProbe _probe;
  final PermissionAsker _ask;
  final PermissionCheck _isGranted;
  final SettingsOpener _openSettings;

  /// **The permission, not the folder, is the question.** The folder opens
  /// either way: Android just hides what is inside it, so a probe that only
  /// asks "can I open this?" answers yes on a phone that shows an empty
  /// library. Android 13 and newer grant the media permissions one by one;
  /// everything before it has the single storage permission.
  Future<bool> hasAccess() async {
    if (await _isGranted(Permission.videos) &&
        await _isGranted(Permission.audio)) {
      return true;
    }
    return _isGranted(Permission.storage);
  }

  /// Returns [MediaAccess.granted] without showing anything when the folder
  /// already reads, so this is safe to call on every launch.
  Future<MediaAccess> ensure() async {
    if (await _granted()) return MediaAccess.granted;

    // Android 13 and newer: the granular media permissions.
    var blocked = await _askSafely(const [Permission.videos, Permission.audio]);
    if (await _granted()) return MediaAccess.granted;

    // Android 12 and older: one storage permission covers the folder. It is
    // asked second because on 13+ it is a no-op that returns "denied", and
    // asking it first would make every phone look blocked.
    blocked = await _askSafely(const [Permission.storage]) || blocked;
    if (await _granted()) return MediaAccess.granted;

    return blocked ? MediaAccess.blocked : MediaAccess.denied;
  }

  /// Granted **and** the folder in place: the folder is created on the way
  /// through, because a first install has none and a missing folder is the
  /// other way this screen used to fail.
  Future<bool> _granted() async {
    if (!await hasAccess()) return false;
    await _probe();
    return true;
  }

  /// **A failing permission channel must not take the app with it.** This
  /// runs at startup, where an unhandled error would reach the user as a
  /// crash instead of as a library that cannot read its folder.
  Future<bool> _askSafely(List<Permission> permissions) async {
    try {
      return await _ask(permissions);
    } on Object {
      return false;
    }
  }

  Future<void> openSettings() => _openSettings();
}

/// Asks for the media permission when the first screen appears.
///
/// **The counterpart of the notification dialog.** The notification
/// permission has an asker inside the notification plugin, this one had
/// none, so a fresh install opened on a library that could not read its own
/// folder and the user was left to find the system settings. When the folder
/// already reads, this probes it and shows nothing.
Future<void> ensureMediaAccessOnStart(WidgetRef ref) async {
  final result = await ref.read(mediaAccessGateProvider).ensure();
  if (result != MediaAccess.granted) return;
  // Only a library that failed on the permission needs rescanning; a healthy
  // one is already loading and must not be restarted.
  final current = ref.read(localMediaProvider);
  if (current.hasError && current.error is MediaAccessDeniedException) {
    ref.invalidate(localMediaProvider);
  }
}
