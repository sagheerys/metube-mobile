import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../di.dart';
import 'update_channel.dart';

/// The current update phase: one source read by both the sheet and the
/// settings row.
enum UpdatePhase { idle, checking, available, downloading, ready, failed }

/// The failure reason **as a code, not as text**: state carries no
/// interface strings (TRD §3.3), and translation happens only at display
/// time.
enum UpdateFailure { check, download, install }

class UpdateState {
  const UpdateState({
    this.phase = UpdatePhase.idle,
    this.release,
    this.apkPath,
    this.progress = 0,
    this.failure,
    this.checkedAt,
    this.upToDate = false,
    this.autoCheck = true,
  });

  final UpdatePhase phase;
  final UpdateRelease? release;

  /// The update file's path once the download completes.
  final String? apkPath;
  final double progress;
  final UpdateFailure? failure;
  final DateTime? checkedAt;

  /// The result of a **manual check** that found nothing new. It is never
  /// shown after a silent automatic check.
  final bool upToDate;
  final bool autoCheck;

  bool get busy =>
      phase == UpdatePhase.checking || phase == UpdatePhase.downloading;

  UpdateState copyWith({
    UpdatePhase? phase,
    UpdateRelease? release,
    String? apkPath,
    double? progress,
    UpdateFailure? failure,
    DateTime? checkedAt,
    bool? upToDate,
    bool? autoCheck,
    bool clearFailure = false,
    bool clearRelease = false,
  }) => UpdateState(
    phase: phase ?? this.phase,
    release: clearRelease ? null : (release ?? this.release),
    apkPath: clearRelease ? null : (apkPath ?? this.apkPath),
    progress: progress ?? this.progress,
    failure: clearFailure ? null : (failure ?? this.failure),
    checkedAt: checkedAt ?? this.checkedAt,
    upToDate: upToDate ?? this.upToDate,
    autoCheck: autoCheck ?? this.autoCheck,
  );
}

final updatePrefsProvider = Provider(
  (ref) => UpdatePrefs(
    store: ref.watch(keyValueStoreProvider),
    mutex: ref.watch(prefsMutexProvider),
  ),
);

/// **The marker identifies this app's file** in a release carrying both
/// apps' APKs.
final updateCheckerProvider = Provider(
  (ref) => UpdateChecker(fetch: ioHttpGetString, assetMarker: 'super'),
);

final apkDownloaderProvider = Provider((ref) => ApkDownloader());

/// The cache folder the update file lands in. **A provider of its own** so
/// tests can replace it with a temporary directory: `path_provider` is a
/// native channel and does not work in widget tests.
final updateCacheDirProvider = FutureProvider<String>(
  (ref) async => (await getTemporaryDirectory()).path,
);

final updateChannelProvider = Provider((ref) => const UpdateChannel());

final updateControllerProvider = NotifierProvider<UpdateNotifier, UpdateState>(
  UpdateNotifier.new,
);

class UpdateNotifier extends Notifier<UpdateState> {
  DownloadCancelToken? _cancel;

  @override
  UpdateState build() {
    unawaited(_loadPrefs());
    return const UpdateState();
  }

  Future<void> _loadPrefs() async {
    final prefs = ref.read(updatePrefsProvider);
    final auto = await prefs.autoCheck();
    final last = await prefs.lastCheck();
    state = state.copyWith(autoCheck: auto, checkedAt: last);
    unawaited(_sweepInstalledApk(prefs));
  }

  /// **Deletes the update file once it has done its job.** Without this,
  /// about 40MB stays in the app cache forever after the first successful
  /// update: the version that was downloaded is now the running version, so
  /// the file helps nobody.
  ///
  /// Compared by version rather than by existence: someone who downloaded
  /// the update, postponed installing and closed the app must find their
  /// file as they left it.
  Future<void> _sweepInstalledApk(UpdatePrefs prefs) async {
    final downloaded = AppVersion.tryParse(await prefs.downloadedVersion());
    if (downloaded == null) return;
    final current = AppVersion.tryParse(await _currentVersion());
    if (current == null || current < downloaded) return;
    try {
      final dir = await ref.read(updateCacheDirProvider.future);
      final file = File('$dir/${MTConstants.updateApkFileName}');
      if (file.existsSync()) await file.delete();
    } catch (_) {
      // The cache is unavailable; the system sweeps it under pressure
      // anyway.
    }
    await prefs.clearDownloaded();
  }

  Future<String> _currentVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  /// **Stamped before the request, not after**: a request that hangs until
  /// the timeout would otherwise allow a fresh check on every quick
  /// consecutive launch.
  Future<void> checkSilently() async {
    if (state.busy || state.release != null) return;
    final prefs = ref.read(updatePrefsProvider);
    if (!await prefs.autoCheck()) return;
    final now = DateTime.now();
    if (!UpdateChecker.isDue(await prefs.lastCheck(), now)) return;
    // **Stamped before the request, not after**: a request that hangs until
    // the timeout would otherwise allow a fresh check on every quick
    // consecutive launch.
    await prefs.markChecked(now);
    final release = await ref
        .read(updateCheckerProvider)
        .check(
          currentVersion: await _currentVersion(),
          skippedVersion: await prefs.skippedVersion(),
        );
    state = release == null
        ? state.copyWith(checkedAt: now)
        : state.copyWith(
            phase: UpdatePhase.available,
            release: release,
            checkedAt: now,
          );
  }

  /// A manual check: it always shows the result, **including a failure**.
  ///
  /// It does not honour "skip this version": whoever pressed the button
  /// wants to know.
  Future<void> checkNow() async {
    if (state.busy) return;
    state = state.copyWith(
      phase: UpdatePhase.checking,
      upToDate: false,
      clearFailure: true,
    );
    final prefs = ref.read(updatePrefsProvider);
    final now = DateTime.now();
    await prefs.markChecked(now);
    try {
      final release = await ref
          .read(updateCheckerProvider)
          .checkOrThrow(currentVersion: await _currentVersion());
      state = state.copyWith(
        phase: release == null ? UpdatePhase.idle : UpdatePhase.available,
        release: release,
        upToDate: release == null,
        checkedAt: now,
        clearRelease: release == null,
      );
    } catch (_) {
      state = state.copyWith(
        phase: UpdatePhase.failed,
        failure: UpdateFailure.check,
        checkedAt: now,
      );
    }
  }

  Future<void> download() async {
    final release = state.release;
    if (release == null || state.phase == UpdatePhase.downloading) return;
    final token = DownloadCancelToken();
    _cancel = token;
    state = state.copyWith(
      phase: UpdatePhase.downloading,
      progress: 0,
      clearFailure: true,
    );
    try {
      final dir = await ref.read(updateCacheDirProvider.future);
      final path = '$dir/${MTConstants.updateApkFileName}';
      await ref
          .read(apkDownloaderProvider)
          .download(
            url: release.apkUrl,
            savePath: path,
            expectedSize: release.apkSize,
            cancel: token,
            onProgress: (p) {
              if (!identical(_cancel, token)) return;
              // **A 1% step rather than every chunk**: chunks are 64KB, so
              // a 40MB file gives about 640 callbacks, one rebuild each,
              // with no difference any eye could see.
              if (p < 1 && (p - state.progress).abs() < 0.01) return;
              state = state.copyWith(progress: p);
            },
          );
      await ref
          .read(updatePrefsProvider)
          .setDownloadedVersion(release.version.toString());
      state = state.copyWith(
        phase: UpdatePhase.ready,
        progress: 1,
        apkPath: path,
      );
    } on UpdateCancelledException {
      // Cancelling returns to "available" rather than a failure; the button
      // offers "download" again.
      state = state.copyWith(phase: UpdatePhase.available, progress: 0);
    } catch (_) {
      state = state.copyWith(
        phase: UpdatePhase.failed,
        failure: UpdateFailure.download,
      );
    } finally {
      if (identical(_cancel, token)) _cancel = null;
    }
  }

  void cancelDownload() => _cancel?.cancel();

  /// `false` means the install permission is missing, and the interface
  /// shows the permission dialog.
  Future<bool> install() async {
    final path = state.apkPath;
    if (path == null) return true;
    final channel = ref.read(updateChannelProvider);
    if (!await channel.canInstall()) return false;
    if (!await channel.install(path)) {
      state = state.copyWith(
        phase: UpdatePhase.failed,
        failure: UpdateFailure.install,
      );
    }
    return true;
  }

  Future<void> openInstallSettings() =>
      ref.read(updateChannelProvider).openInstallSettings();

  Future<void> setAutoCheck(bool value) async {
    await ref.read(updatePrefsProvider).setAutoCheck(value);
    state = state.copyWith(autoCheck: value);
  }

  /// Mutes this release alone; anything newer appears automatically.
  Future<void> skipCurrent() async {
    final release = state.release;
    if (release == null) return;
    await ref.read(updatePrefsProvider).skipVersion(release.version.toString());
    state = state.copyWith(
      phase: UpdatePhase.idle,
      clearRelease: true,
      clearFailure: true,
    );
  }

  /// "Later": hides the card for this session without muting it
  /// permanently.
  void dismiss() => state = state.copyWith(
    phase: UpdatePhase.idle,
    clearRelease: true,
    clearFailure: true,
  );
}
