import 'dart:io';

import 'transfer.dart';

/// **Sweeping orphaned partial files (fix خ-3).**
///
/// Killing the app in the middle of a large pull leaves `<name>.part` on
/// disk, and the new name after a retry differs because of the `HHmmss`
/// stamp, so nobody ever cleans the old one — and **neither app swept at
/// startup**. The library scan skips `.part` on purpose, so the space is
/// lost without the user ever seeing it.
///
/// [olderThan] protects a pull **happening right now** from being swept
/// out from under it.
Future<int> sweepPartialFiles(
  String directoryPath, {
  Duration olderThan = const Duration(hours: 6),
}) async {
  final dir = Directory(directoryPath);
  if (!await dir.exists()) return 0;
  final cutoff = DateTime.now().subtract(olderThan);
  var removed = 0;
  try {
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith(Transfer.partSuffix)) continue;
      try {
        final stat = await entity.stat();
        if (stat.modified.isAfter(cutoff)) continue;
        await entity.delete();
        removed++;
      } on FileSystemException {
        // A locked file, or one deleted between the listing and here.
        // Nothing to do.
      }
    }
  } on FileSystemException {
    // A folder with no read permission: no sweep, and no crash at startup.
  }
  return removed;
}
