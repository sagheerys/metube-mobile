import 'package:uuid/uuid.dart';

import '../api/api_exceptions.dart';
import 'quality.dart';

const _uuid = Uuid();

/// The phases of a download task along the four-stage pipeline
/// (`05-DATA-SCHEMA.md` §3): add, poll, pull, delete by policy.
enum TaskPhase {
  queued,
  adding,
  polling,

  /// The file is ready on the server and **the pull is held waiting for
  /// Wi-Fi**.
  ///
  /// A phase of its own rather than part of `pulling`, on purpose: progress
  /// does not move here, and the reason is not a slow network but the
  /// user's
  /// own choice. Showing it as "pulling 0%" is a lie that suggests the app
  /// has hung, and showing it as "failed" is another one.
  waitingForNetwork,
  pulling,
  deleting,
  completed,
  failed,
  cancelled,
}

/// A single download task, identified by a uuid v4 rather than the old and
/// fragile `url.hashCode`. Immutable; the download engine advances it
/// through [copyWith].
class DownloadTask {
  DownloadTask({
    String? id,
    required this.inputUrl,
    required this.quality,
    this.resolvedUrl,
    this.canonicalUrl,
    this.serverFilename,
    this.title,
    this.thumbnail,
    this.localPath,
    this.phase = TaskPhase.queued,
    this.progress = 0,
    this.error,
    this.isBatchMember = false,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  final String id;

  /// As the user entered it, for display and for retrying.
  final String inputUrl;

  /// After the short link is resolved. This is what is sent to `/add`.
  final String? resolvedUrl;

  /// From `/history`. The **only** value valid for deletion and indexing.
  final String? canonicalUrl;
  final String? serverFilename;

  /// The server's title and artwork at the moment of completion. Used for
  /// the local filename (§2.4), the title and artwork indexes and the
  /// completion notification. **Neither is invented** when missing (trap
  /// §6.3).
  final String? title;
  final String? thumbnail;
  final String? localPath;
  final Quality quality;
  final TaskPhase phase;

  /// 0 to 1: the server's progress while polling, then the pull's progress
  /// while pulling.
  final double progress;

  /// The classified error on failure. The app turns its type into
  /// translated
  /// text (TRD §3.3).
  final MTApiException? error;

  /// A single item outranks members of a batch in the queue.
  final bool isBatchMember;
  final DateTime createdAt;

  /// **Does this phase have known progress?** A waiting task and one held
  /// by
  /// the network gate do not move, so showing "0%" over them is a lie that
  /// suggests a hang (the same reasoning as `waitingForNetwork`).
  bool get hasKnownProgress =>
      phase != TaskPhase.queued && phase != TaskPhase.waitingForNetwork;

  bool get isFinished =>
      phase == TaskPhase.completed ||
      phase == TaskPhase.failed ||
      phase == TaskPhase.cancelled;

  String get effectiveUrl => resolvedUrl ?? inputUrl;

  DownloadTask copyWith({
    String? resolvedUrl,
    String? canonicalUrl,
    String? serverFilename,
    String? title,
    String? thumbnail,
    String? localPath,
    TaskPhase? phase,
    double? progress,
    MTApiException? error,
  }) =>
      DownloadTask(
        id: id,
        inputUrl: inputUrl,
        quality: quality,
        resolvedUrl: resolvedUrl ?? this.resolvedUrl,
        canonicalUrl: canonicalUrl ?? this.canonicalUrl,
        serverFilename: serverFilename ?? this.serverFilename,
        title: title ?? this.title,
        thumbnail: thumbnail ?? this.thumbnail,
        localPath: localPath ?? this.localPath,
        phase: phase ?? this.phase,
        progress: progress ?? this.progress,
        error: error ?? this.error,
        isBatchMember: isBatchMember,
        createdAt: createdAt,
      );
}

/// The mean progress of a group of tasks (0 to 1), for the summary bar at
/// the top of the library when several downloads run at once (field report
/// 2026-09-03).
///
/// Tasks with no known progress count as **zero rather than being
/// excluded**: excluding them made "3 downloads" show 90% because only one
/// was running and the rest were queued. An empty group, or one with no
/// progress at all, yields `null` for an indeterminate bar.
double? averageTaskProgress(List<DownloadTask> tasks) {
  if (tasks.isEmpty) return null;
  if (!tasks.any((t) => t.hasKnownProgress)) return null;
  var sum = 0.0;
  for (final task in tasks) {
    if (task.hasKnownProgress) sum += task.progress.clamp(0, 1);
  }
  return sum / tasks.length;
}
