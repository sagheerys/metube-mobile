import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import 'package:package_info_plus/package_info_plus.dart';

import '../di.dart';

/// The running version. A provider of its own so a test can name one:
/// package_info_plus reads the executable, which a test does not have.
final installedVersionProvider = FutureProvider<String>(
  (ref) async => (await PackageInfo.fromPlatform()).version,
);

/// Whether "what's new" is looked for at start-up: the real app only, so
/// a test of the shell never reaches GitHub.
final offerWhatsNewProvider = Provider<bool>((ref) => false);

/// The releases, read from the same repository the phones read. Windows
/// files carry `Ember` in their names.
final updateCheckerProvider = Provider(
  (ref) => UpdateChecker(
    fetch: ioHttpGetString,
    assetMarker: 'ember',
    assetExtension: '.exe',
  ),
);

/// Where an update stands; the settings section and the start-up notice
/// read the same state.
enum UpdatePhase { idle, checking, available, downloading, failed }

/// Why it failed, as a code: the words are chosen where it is shown.
enum UpdateFailure { check, download, install }

class UpdateState {
  const UpdateState({
    this.phase = UpdatePhase.idle,
    this.release,
    this.progress = 0,
    this.failure,
    this.checkedAt,
    this.upToDate = false,
    this.autoCheck = true,
  });

  final UpdatePhase phase;
  final UpdateRelease? release;
  final double progress;
  final UpdateFailure? failure;
  final DateTime? checkedAt;

  /// A check the user asked for found nothing new; never said after a
  /// silent check.
  final bool upToDate;
  final bool autoCheck;

  bool get busy =>
      phase == UpdatePhase.checking || phase == UpdatePhase.downloading;

  UpdateState copyWith({
    UpdatePhase? phase,
    UpdateRelease? release,
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
    progress: progress ?? this.progress,
    failure: clearFailure ? null : (failure ?? this.failure),
    checkedAt: checkedAt ?? this.checkedAt,
    upToDate: upToDate ?? this.upToDate,
    autoCheck: autoCheck ?? this.autoCheck,
  );
}

/// Starts the downloaded installer and closes the app, which the installer
/// opens again when it is done. False when it could not be started.
typedef InstallerLauncher = Future<bool> Function(String path);

/// Overridden in main; a test or a run without the window starts nothing.
final installerLauncherProvider = Provider<InstallerLauncher>(
  (ref) =>
      (_) async => false,
);

/// The folder the installer is downloaded to: Windows' temporary folder,
/// which it empties itself.
final updateFolderProvider = Provider<String>(
  (ref) => Directory.systemTemp.path,
);

final updatePrefsProvider = Provider(
  (ref) => UpdatePrefs(
    store: ref.watch(keyValueStoreProvider),
    mutex: ref.watch(prefsMutexProvider),
  ),
);

/// The installer must start as a Windows program would: an error page
/// saved under its name would otherwise be run.
final installerDownloaderProvider = Provider(
  (ref) => ApkDownloader(magic: ApkDownloader.exeMagic),
);

final updateProvider = NotifierProvider<UpdateNotifier, UpdateState>(
  UpdateNotifier.new,
);

/// The installer's file name for [version], as the release names it. The
/// version comes from the release's tag, and the name becomes a path in
/// the temporary folder that is written, run and deleted: anything but
/// letters, digits and dots becomes `_`, so no tag climbs out of it.
String installerNameFor(String version) =>
    'MeTube-Ember-${version.replaceAll(RegExp('[^0-9A-Za-z.]'), '_')}'
    '-windows-x64-setup.exe';

class UpdateNotifier extends Notifier<UpdateState> {
  DownloadCancelToken? _cancel;

  @override
  UpdateState build() {
    unawaited(_load());
    return const UpdateState();
  }

  UpdatePrefs get _prefs => ref.read(updatePrefsProvider);

  Future<void> _load() async {
    try {
      final auto = await _prefs.autoCheck();
      final last = await _prefs.lastCheck();
      state = state.copyWith(autoCheck: auto, checkedAt: last);
      await _sweep();
    } on Object {
      // Storage unreadable: the defaults stand.
    }
  }

  /// The installer of the version now running has done its job; the file
  /// goes. One for a newer version stays, for an update put off.
  Future<void> _sweep() async {
    final downloaded = await _prefs.downloadedVersion();
    final kept = AppVersion.tryParse(downloaded);
    final current = AppVersion.tryParse(await _current());
    if (kept == null || current == null || current < kept) return;
    final file = File(_pathFor(downloaded!));
    if (file.existsSync()) await file.delete();
    await _prefs.clearDownloaded();
  }

  String _pathFor(String version) =>
      '${ref.read(updateFolderProvider)}\\${installerNameFor(version)}';

  Future<String> _current() => ref.read(installedVersionProvider.future);

  /// At start-up, out of sight: no spinner and no error, whatever happens.
  Future<void> checkSilently() async {
    if (state.busy || state.release != null) return;
    try {
      if (!await _prefs.autoCheck()) return;
      final now = DateTime.now();
      if (!UpdateChecker.isDue(await _prefs.lastCheck(), now)) return;
      await _prefs.markChecked(now);
      final release = await ref
          .read(updateCheckerProvider)
          .check(
            currentVersion: await _current(),
            skippedVersion: await _prefs.skippedVersion(),
          );
      if (release != null) await _keepNotes(release);
      state = release == null
          ? state.copyWith(checkedAt: now)
          : state.copyWith(
              phase: UpdatePhase.available,
              release: release,
              checkedAt: now,
            );
    } on Object {
      // A silent check never troubles anyone.
    }
  }

  /// The button: says what it found, a failure included, and does not
  /// honour "skip this version", since whoever asked wants to know.
  Future<void> checkNow() async {
    if (state.busy) return;
    state = state.copyWith(
      phase: UpdatePhase.checking,
      upToDate: false,
      clearFailure: true,
    );
    final now = DateTime.now();
    try {
      await _prefs.markChecked(now);
      final release = await ref
          .read(updateCheckerProvider)
          .checkOrThrow(currentVersion: await _current());
      if (release != null) await _keepNotes(release);
      state = state.copyWith(
        phase: release == null ? UpdatePhase.idle : UpdatePhase.available,
        release: release,
        upToDate: release == null,
        checkedAt: now,
        clearRelease: release == null,
      );
    } on Object {
      state = state.copyWith(
        phase: UpdatePhase.failed,
        failure: UpdateFailure.check,
        checkedAt: now,
      );
    }
  }

  /// "What's new" after the update shows these notes without a network.
  Future<void> _keepNotes(UpdateRelease release) =>
      _prefs.saveNotes(release.version.toString(), release.notes);

  /// Downloads the installer, then starts it; the app closes and the
  /// installer opens it again, updated.
  Future<void> install() async {
    final release = state.release;
    if (release == null || state.busy) return;
    final token = DownloadCancelToken();
    _cancel = token;
    state = state.copyWith(
      phase: UpdatePhase.downloading,
      progress: 0,
      clearFailure: true,
    );
    final version = release.version.toString();
    final path = _pathFor(version);
    try {
      await ref
          .read(installerDownloaderProvider)
          .download(
            url: release.apkUrl,
            savePath: path,
            expectedSize: release.apkSize,
            sha256: release.sha256,
            cancel: token,
            onProgress: (p) {
              if (!identical(_cancel, token)) return;
              // A step of a percent, not a rebuild for every chunk.
              if (p < 1 && (p - state.progress).abs() < 0.01) return;
              state = state.copyWith(progress: p);
            },
          );
    } on UpdateCancelledException {
      state = state.copyWith(phase: UpdatePhase.available, progress: 0);
      return;
    } on Object {
      state = state.copyWith(
        phase: UpdatePhase.failed,
        failure: UpdateFailure.download,
      );
      return;
    } finally {
      if (identical(_cancel, token)) _cancel = null;
    }
    await _prefs.setDownloadedVersion(version);
    if (!await ref.read(installerLauncherProvider)(path)) {
      state = state.copyWith(
        phase: UpdatePhase.failed,
        failure: UpdateFailure.install,
      );
    }
  }

  void cancel() => _cancel?.cancel();

  Future<void> setAutoCheck(bool on) async {
    state = state.copyWith(autoCheck: on);
    await _prefs.setAutoCheck(on);
  }

  /// Mutes this release; anything newer is offered again.
  Future<void> skip() async {
    final release = state.release;
    if (release == null) return;
    await _prefs.skipVersion(release.version.toString());
    later();
  }

  /// Out of sight for now, offered again at the next check.
  void later() => state = state.copyWith(
    phase: UpdatePhase.idle,
    clearRelease: true,
    clearFailure: true,
  );
}
