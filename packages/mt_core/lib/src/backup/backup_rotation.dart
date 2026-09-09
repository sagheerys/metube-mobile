import 'dart:io';

/// A backup saved on disk. Its name carries its date, so the file never
/// has to be read to sort it.
class BackupFile {
  const BackupFile({
    required this.path,
    required this.name,
    required this.at,
    required this.sizeBytes,
  });

  final String path;
  final String name;
  final DateTime at;
  final int sizeBytes;
}

/// **The rotating backup store** (requested 2026-09-04: "several copies, up
/// to seven automatically, deleting the oldest").
///
/// Four decisions, each one caused by a real failure:
///
/// 1. **A dated name per copy, not one file overwritten.** A fixed
///    name meant a corrupt copy erased the good one before it with no way
///    back. And it bit from another direction too: Android 11+ records an
///    **owner** for every file in `Download/`, so a reinstalled app cannot
///    overwrite a file an earlier install created, which is the `errno 13`
///    seen in a screenshot. A new name every time makes the conflict
///    structurally impossible.
///
/// 2. **Atomic writes**: `.tmp` then rename. An interruption
///    mid-write, a killed app or a dead battery, never leaves half a file
///    that looks valid.
///
/// 3. **A copy identical to the newest one is not written.** Without
///    this the seven become seven consecutive moments rather than seven
///    changes, and yesterday's copy is evicted by today's duplicates.
///
/// 4. **A minimum spacing between slots** ([minSpacing]), added after
///    a device review (2026-09-05): all seven copies in Super sat between
///    00:39 and 00:45, **six minutes covering the entire backup history**.
///    The limit of seven was working perfectly, but every playlist or tag
///    change requests a backup, and a batch download from YouTube is a
///    change per clip, so one batch consumed all seven slots and evicted
///    everything before it. Decision 3 does not help here: each copy really
///    is different from the one before.
///
/// So a copy newer than [minSpacing] **replaces** the one before it in the
/// same slot rather than opening a new one: the latest state is always
/// saved, and the seven span hours or days depending on how the app is
/// used.
class BackupRotation {
  BackupRotation({
    required this.directory,
    required this.prefix,
    this.keep = defaultKeep,
    this.minSpacing = defaultSpacing,
  }) : assert(keep > 0, 'الاحتفاظ بصفر نسخة يعني حذف كل شيء');

  /// The agreed count. The file is a few kilobytes, and a fixed number is
  /// clearer to a user than a time-based schedule.
  static const int defaultKeep = 7;

  /// One hour: a full batch download stays one slot, while a normal day of
  /// use leaves several, so the seven become a history rather than a
  /// repeated snapshot.
  static const Duration defaultSpacing = Duration(hours: 1);

  static const String extension = '.json';
  static const String _tempExtension = '.tmp';

  /// The backup folder: `<app media>/backups`.
  final String directory;

  /// The name prefix: `metube_lite` or `metube_super`.
  final String prefix;

  final int keep;

  /// The minimum gap between two slots. `Duration.zero` disables spacing.
  final Duration minSpacing;

  /// `prefix_2026-09-04_094233.json`: sorting alphabetically sorts
  /// chronologically.
  String fileNameFor(DateTime at) => '${prefix}_${stampOf(at)}$extension';

  static String stampOf(DateTime at) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${at.year}-${two(at.month)}-${two(at.day)}'
        '_${two(at.hour)}${two(at.minute)}${two(at.second)}';
  }

  /// The date parsed out of the name, or `null` for a name that does not
  /// follow the pattern.
  DateTime? dateOf(String fileName) {
    if (!fileName.startsWith('${prefix}_') || !fileName.endsWith(extension)) {
      return null;
    }
    final stamp = fileName.substring(
      prefix.length + 1,
      fileName.length - extension.length,
    );
    if (stamp.length != 17 || stamp[10] != '_') return null;
    return DateTime.tryParse(
      '${stamp.substring(0, 10)} '
      '${stamp.substring(11, 13)}:${stamp.substring(13, 15)}:'
      '${stamp.substring(15, 17)}',
    );
  }

  /// The saved copies, **newest first**. A missing folder yields an empty
  /// list.
  Future<List<BackupFile>> list() async {
    final dir = Directory(directory);
    if (!await dir.exists()) return const [];
    final out = <BackupFile>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.path.split(RegExp(r'[/\\]')).last;
      final at = dateOf(name);
      if (at == null) continue; // ملفات قديمة أو غريبة لا تُلمس
      out.add(
        BackupFile(
          path: entity.path,
          name: name,
          at: at,
          sizeBytes: await entity.length(),
        ),
      );
    }
    out.sort((a, b) => b.at.compareTo(a.at));
    return out;
  }

  Future<BackupFile?> latest() async => (await list()).firstOrNull;

  /// Writes a new copy and deletes anything beyond [keep].
  ///
  /// Returns `null` when the content is **identical to the newest copy**:
  /// nothing changed, so there is no reason to spend one of the seven
  /// slots.
  Future<BackupFile?> write(String contents, {DateTime? at}) async {
    final dir = Directory(directory);
    await dir.create(recursive: true);

    final stamp = at ?? DateTime.now();
    final newest = await latest();
    if (newest != null) {
      final previous = await File(newest.path).readAsString();
      if (previous == contents) return null;
    }

    // **Replacement rather than addition** inside the same time slot: the
    // old file is deleted after the replacement is written successfully,
    // never before, so an interruption in the middle leaves the old copy
    // intact rather than leaving the user with none.
    //
    // The slot is computed on a **fixed grid**, not as a gap from the last
    // write: "newer than an hour" made activity every half hour drag the
    // single slot forward forever, so a history never opened at all.
    final replace =
        newest != null &&
        minSpacing > Duration.zero &&
        _slotOf(stamp) == _slotOf(newest.at);
    final name = fileNameFor(stamp);
    final target = '$directory/$name';
    final temp = File('$target$_tempExtension');
    await temp.writeAsString(contents, flush: true);
    // The atomic move: only from here is the copy visible to a reader.
    final file = await temp.rename(target);

    if (replace && newest.path != file.path) {
      try {
        await File(newest.path).delete();
      } on FileSystemException {
        // A file owned by an earlier install. Leave it; prune enforces the
        // limit.
      }
    }
    await prune();
    return BackupFile(
      path: file.path,
      name: name,
      at: stamp,
      sizeBytes: await file.length(),
    );
  }

  /// The slot number on the fixed [minSpacing] grid, in practice the
  /// calendar hour.
  int _slotOf(DateTime at) =>
      at.millisecondsSinceEpoch ~/ minSpacing.inMilliseconds;

  /// Deletes the oldest until [keep] remain, and returns how many were
  /// deleted.
  Future<int> prune() async {
    final all = await list();
    if (all.length <= keep) return 0;
    var deleted = 0;
    for (final file in all.skip(keep)) {
      try {
        await File(file.path).delete();
        deleted++;
      } on FileSystemException {
        // A file owned by an earlier install (Android 11+). Leave it, and
        // do not fail the rotation over it.
      }
    }
    return deleted;
  }

  Future<String> read(BackupFile file) => File(file.path).readAsString();
}
