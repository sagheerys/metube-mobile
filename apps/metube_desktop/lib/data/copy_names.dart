import 'dart:io';

import 'package:mt_core/mt_core.dart';

/// [name] as Windows accepts it: the characters it forbids become `_`, and
/// trailing dots and spaces, which it drops silently, go. A name Windows
/// keeps for a device (`CON`, `NUL`, `COM1`…, with any extension) gains a
/// leading `_`, and a name past [maxNameLength] is cut, its extension kept:
/// both come from the server, and either made the copy fail.
String windowsSafeName(String name) {
  final trailing = RegExp(r'[. ]+$');
  var safe = name
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
      .replaceAll(trailing, '');
  if (safe.length > maxNameLength) {
    final dot = safe.lastIndexOf('.');
    final ext = dot > 0 && safe.length - dot <= 10 ? safe.substring(dot) : '';
    final stem = safe.substring(0, maxNameLength - ext.length);
    safe = stem.replaceAll(trailing, '') + ext;
  }
  if (_deviceName.hasMatch(safe)) safe = '_$safe';
  return safe.isEmpty ? '_' : safe;
}

/// The longest file or folder name a copy is given: Windows refuses past
/// 255, and the folder in front of it counts towards the path's limit.
const int maxNameLength = 200;

final RegExp _deviceName = RegExp(
  r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\..*)?$',
  caseSensitive: false,
);

/// The folder below the download folder that a server file keeps on this
/// computer: its folder on the server, each part a name Windows accepts
/// (`..` and `.` become `_`). Empty for a file at the top, and for a path
/// the traversal guard refuses: that copy fails at the guard, and no
/// folder is made on the way there.
String serverSubfolder(String serverPath) {
  if (!ServerPath.isSafe(serverPath)) return '';
  return ServerPath.folderOf(serverPath)
      .split('/')
      .where((part) => part.isNotEmpty)
      .map(windowsSafeName)
      .join(r'\');
}

/// [path], or the same name with " (2)", " (3)"… when taken, as Explorer
/// numbers a copy.
String freeTarget(String path) {
  if (!File(path).existsSync()) return path;
  final slash = path.lastIndexOf('\\');
  final dot = path.lastIndexOf('.');
  final hasExt = dot > slash + 1;
  final stem = hasExt ? path.substring(0, dot) : path;
  final ext = hasExt ? path.substring(dot) : '';
  for (var i = 2; i < 1000; i++) {
    final candidate = '$stem ($i)$ext';
    if (!File(candidate).existsSync()) return candidate;
  }
  return path;
}
