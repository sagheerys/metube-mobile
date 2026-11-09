import 'dart:io';

import 'device_pulls.dart' show PullKind;

/// How long a shared copy stays. The share menu returns before the
/// receiving app has finished reading the file, so deleting it at once
/// broke the share in apps that read it late.
const shareKeep = Duration(hours: 1);

/// The size messaging apps stop at; past it the large-file question says
/// which apps will still take the file.
const shareMessagingBytes = 2 * 1024 * 1024 * 1024;

/// [opening]: the copy is done and the system's share menu is on its way;
/// it can take seconds for a large clip (see `mtShareWithNotice`).
enum SharePhase { pulling, ready, opening, failed }

/// The share in flight, as the sheet shows it. How far the copy has got
/// is read from the copy itself, [kind] saying which one: the share's own,
/// or an offline copy of the same clip already running.
class ShareJob {
  const ShareJob({
    required this.url,
    required this.title,
    this.kind = PullKind.share,
    this.phase = SharePhase.pulling,
    this.error,
  });

  final String url;
  final String title;
  final PullKind kind;
  final SharePhase phase;
  final Object? error;

  ShareJob copyWith({SharePhase? phase, Object? error}) => ShareJob(
    url: url,
    title: title,
    kind: kind,
    phase: phase ?? this.phase,
    error: error ?? this.error,
  );
}

/// A smoothed speed. A raw reading per callback jumps around too much to
/// read, so each sample a half second apart moves it a third of the way.
class TransferRate {
  static const _every = Duration(milliseconds: 500);

  Duration? _at;
  int _received = 0;
  double? value;

  double? sample(int received, Duration at) {
    final last = _at;
    if (last == null) {
      _at = at;
      _received = received;
      return value;
    }
    final gap = at - last;
    if (gap < _every) return value;
    final now = (received - _received) * 1000 / gap.inMilliseconds;
    value = value == null ? now : value! + (now - value!) / 3;
    _at = at;
    _received = received;
    return value;
  }
}

/// Deletes copies kept past [shareKeep], and partial files a killed pull
/// left behind. Run at startup and before each share, so the folder never
/// holds more than the last hour's shares.
Future<int> sweepShareFolder(
  String path, {
  Duration olderThan = shareKeep,
}) async {
  final cutoff = DateTime.now().subtract(olderThan);
  var removed = 0;
  try {
    final dir = Directory(path);
    if (!await dir.exists()) return 0;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      try {
        if ((await entity.stat()).modified.isAfter(cutoff)) continue;
        await entity.delete();
        removed++;
      } on FileSystemException {
        // Still open in the receiving app; the next sweep takes it.
      }
    }
  } on FileSystemException {
    // No cache folder to read; nothing to sweep.
  }
  return removed;
}
