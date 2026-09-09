import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../di.dart';
import 'update_channel.dart';

/// طور التحديث الحالي — مصدر واحد تقرؤه الورقة وصفّ الإعدادات معاً.
enum UpdatePhase { idle, checking, available, downloading, ready, failed }

/// سبب الفشل **رمزاً لا نصاً**: الحالة لا تحمل نص واجهة (TRD §3.3)،
/// والترجمة تحدث عند العرض وحده.
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

  /// مسار ملف التحديث بعد اكتمال التنزيل.
  final String? apkPath;
  final double progress;
  final UpdateFailure? failure;
  final DateTime? checkedAt;

  /// نتيجة **فحص يدوي** لم يجد جديداً — لا تُعرض بعد فحص تلقائي صامت.
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
  }) =>
      UpdateState(
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

final updatePrefsProvider = Provider((ref) => UpdatePrefs(
      store: ref.watch(keyValueStoreProvider),
      mutex: ref.watch(prefsMutexProvider),
    ));

/// **العلامة تميّز ملف هذا التطبيق** في إصدار يحمل APK التطبيقين معاً.
final updateCheckerProvider = Provider(
    (ref) => UpdateChecker(fetch: ioHttpGetString, assetMarker: 'super'));

final apkDownloaderProvider = Provider((ref) => ApkDownloader());

/// مجلد الكاش الذي يحطّ فيه ملف التحديث — **مزوّد مستقل** كي تستبدله
/// الاختبارات بمجلد مؤقّت: `path_provider` قناة أصلية لا تعمل في
/// اختبارات الودجات.
final updateCacheDirProvider = FutureProvider<String>(
    (ref) async => (await getTemporaryDirectory()).path);

final updateChannelProvider = Provider((ref) => const UpdateChannel());

final updateControllerProvider =
    NotifierProvider<UpdateNotifier, UpdateState>(UpdateNotifier.new);

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
  }

  Future<String> _currentVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  /// فحص صامت عند الإقلاع: لا مؤشر انتظار ولا رسالة خطأ مهما جرى.
  Future<void> checkSilently() async {
    if (state.busy || state.release != null) return;
    final prefs = ref.read(updatePrefsProvider);
    if (!await prefs.autoCheck()) return;
    final now = DateTime.now();
    if (!UpdateChecker.isDue(await prefs.lastCheck(), now)) return;
    // **يُختم قبل الطلب لا بعده**: طلب يعلّق حتى المهلة كان سيسمح بفحص
    // جديد عند كل إقلاع متتالٍ سريع.
    await prefs.markChecked(now);
    final release = await ref.read(updateCheckerProvider).check(
          currentVersion: await _currentVersion(),
          skippedVersion: await prefs.skippedVersion(),
        );
    state = release == null
        ? state.copyWith(checkedAt: now)
        : state.copyWith(
            phase: UpdatePhase.available, release: release, checkedAt: now);
  }

  /// فحص يدوي: يعرض النتيجة دائماً، **بما فيها الفشل**.
  ///
  /// لا يحترم «تخطّي هذا الإصدار»: من ضغط الزر بنفسه يريد أن يعرف.
  Future<void> checkNow() async {
    if (state.busy) return;
    state = state.copyWith(
        phase: UpdatePhase.checking, upToDate: false, clearFailure: true);
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
          checkedAt: now);
    }
  }

  Future<void> download() async {
    final release = state.release;
    if (release == null || state.phase == UpdatePhase.downloading) return;
    final token = DownloadCancelToken();
    _cancel = token;
    state = state.copyWith(
        phase: UpdatePhase.downloading, progress: 0, clearFailure: true);
    try {
      final dir = await ref.read(updateCacheDirProvider.future);
      final path = '$dir/${MTConstants.updateApkFileName}';
      await ref.read(apkDownloaderProvider).download(
            url: release.apkUrl,
            savePath: path,
            expectedSize: release.apkSize,
            cancel: token,
            onProgress: (p) {
              if (identical(_cancel, token)) {
                state = state.copyWith(progress: p);
              }
            },
          );
      state =
          state.copyWith(phase: UpdatePhase.ready, progress: 1, apkPath: path);
    } on UpdateCancelledException {
      // الإلغاء عودة إلى «متاح» لا فشل — الزر يعرض «تنزيل» من جديد.
      state = state.copyWith(phase: UpdatePhase.available, progress: 0);
    } catch (_) {
      state = state.copyWith(
          phase: UpdatePhase.failed, failure: UpdateFailure.download);
    } finally {
      if (identical(_cancel, token)) _cancel = null;
    }
  }

  void cancelDownload() => _cancel?.cancel();

  /// `false` ⇒ إذن التثبيت ناقص، والواجهة تعرض حوار الإذن حينها.
  Future<bool> install() async {
    final path = state.apkPath;
    if (path == null) return true;
    final channel = ref.read(updateChannelProvider);
    if (!await channel.canInstall()) return false;
    if (!await channel.install(path)) {
      state = state.copyWith(
          phase: UpdatePhase.failed, failure: UpdateFailure.install);
    }
    return true;
  }

  Future<void> openInstallSettings() =>
      ref.read(updateChannelProvider).openInstallSettings();

  Future<void> setAutoCheck(bool value) async {
    await ref.read(updatePrefsProvider).setAutoCheck(value);
    state = state.copyWith(autoCheck: value);
  }

  /// يكتم هذا الإصدار وحده — الأحدث منه يظهر تلقائياً.
  Future<void> skipCurrent() async {
    final release = state.release;
    if (release == null) return;
    await ref.read(updatePrefsProvider).skipVersion(release.version.toString());
    state = state.copyWith(
        phase: UpdatePhase.idle, clearRelease: true, clearFailure: true);
  }

  /// «لاحقاً»: يُخفي البطاقة لهذه الجلسة بلا كتم دائم.
  void dismiss() => state = state.copyWith(
      phase: UpdatePhase.idle, clearRelease: true, clearFailure: true);
}
