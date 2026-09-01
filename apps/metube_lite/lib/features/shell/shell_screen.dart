import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../downloads_library/library_enricher.dart';
import '../downloads_library/library_providers.dart';
import '../home/add_flow.dart';
import '../home/download_watcher.dart';
import '../home/reception.dart';
import '../player/playback_providers.dart';
import '../settings/restore_prompt.dart';

/// غلاف النموذج أ: 3 وجهات سفلية + الطبقة العائمة (زر الإضافة الذكي) —
/// الزر يظهر في المكتبة والقوائم ويختفي في الإعدادات.
class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen>
    with WidgetsBindingObserver {
  ShareReceiver? _shareReceiver;

  /// م-18/م-35: سبر الملفات المهاجَرة (غلاف + أبعاد) بعمر التطبيق —
  /// يُراقَب هنا لا في شاشة المكتبة كي لا يتوقف عند مغادرتها.
  void _watchEnrichment() => ref.watch(libraryEnrichmentProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shareReceiver = ShareReceiver(onUrls: _onSharedUrls);
    _shareReceiver!.start();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(clipboardRefresherProvider)();
      // م-21: إحياء جلسة الصوت المحفوظة (بلا تشغيل تلقائي).
      ref.read(audioHandlerProvider).restoreSession();
      await initDownloadNotifications(ref);
      if (mounted) await maybeOfferAutoRestore(context, ref);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(clipboardRefresherProvider)();
      // ملفات قد تكون تغيّرت من خارج التطبيق (حذف من المعرض مثلاً).
      ref.invalidate(localMediaProvider);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shareReceiver?.dispose();
    super.dispose();
  }

  /// م-3: مشاركة خارجية ⇒ فتح `/` وبدء ر-2 (عدة روابط = إرسال متتابع).
  void _onSharedUrls(List<String> urls) {
    if (!mounted || urls.isEmpty) return;
    widget.navigationShell.goBranch(0);
    if (urls.length == 1) {
      openAddSheet(context, ref, initialUrl: urls.first);
      return;
    }
    final engine = ref.read(downloadEngineProvider);
    if (engine == null) return;
    final quality = ref.read(settingsProvider).quality;
    for (final url in urls) {
      if (PlaylistDetector.isPlaylist(url)) {
        GoRouter.of(context).push('/batch', extra: url);
      } else {
        engine.submit(url, quality, isBatchMember: true);
      }
    }
    showMTSnack(context, context.mtl.downloadStarted,
        type: MTSnackType.success);
  }

  /// م-2: رابط جاهز بالحافظة ⇒ تنفيذ مباشر عند الضغط.
  void _onFabPressed() {
    final clipboardUrl = ref.read(clipboardUrlProvider);
    if (clipboardUrl != null) {
      final engine = ref.read(downloadEngineProvider);
      if (engine != null && !PlaylistDetector.isPlaylist(clipboardUrl)) {
        engine.submit(clipboardUrl, ref.read(settingsProvider).quality);
        ref.read(clipboardUrlProvider.notifier).state = null;
        showMTSnack(context, context.mtl.downloadStarted,
            type: MTSnackType.success);
        return;
      }
      openAddSheet(context, ref, initialUrl: clipboardUrl);
      return;
    }
    openAddSheet(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final branch = widget.navigationShell.currentIndex;
    final clipboardUrl = ref.watch(clipboardUrlProvider);

    // يبقى محقونًا حياً ليقود الإشعارات ووضع الخلفية (م-9/م-10).
    ref.watch(downloadWatcherProvider);
    _watchEnrichment();

    return Scaffold(
      body: widget.navigationShell,
      floatingActionButton: branch == 2
          ? null
          // يختفي تحت أي ورقة أو حوار: كان يحجب رابط «حول المقطع»
          // ويزاحم أفعال القوائم السفلية (بلاغ المالك 2026-09-02).
          : MTHiddenUnderRoutes(
              child: MTFab(
                label: clipboardUrl == null
                    ? l10n.addLinkFab
                    : l10n.clipboardLinkReady,
                highlighted: clipboardUrl != null,
                onPressed: _onFabPressed,
              ),
            ),
      // م-22: المشغل المصغر شريط دائم **فوق** الشريط السفلي — داخل نفس
      // الفتحة ليحسب Scaffold مساحته ويرفع زر الإضافة فوقه (سجل §4).
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (branch != 2)
            MTMiniPlayer(
              handler: ref.watch(audioHandlerProvider),
              artwork: artworkBuilderFor(ref),
              onOpen: () => GoRouter.of(context).push('/audio'),
            ),
          _navigationBar(l10n, branch),
        ],
      ),
    );
  }

  NavigationBar _navigationBar(MTLocalizations l10n, int branch) =>
      NavigationBar(
        selectedIndex: branch,
        onDestinationSelected: widget.navigationShell.goBranch,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.download_outlined),
            selectedIcon: const Icon(Icons.download_rounded),
            label: l10n.navMyDownloads,
          ),
          NavigationDestination(
            icon: const Icon(Icons.queue_music_outlined),
            selectedIcon: const Icon(Icons.queue_music_rounded),
            label: l10n.navPlaylists,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: l10n.navSettings,
          ),
        ],
      );
}

/// دالة فحص الحافظة قابلة للاستدعاء من الغلاف.
final clipboardRefresherProvider =
    Provider<Future<void> Function()>((ref) => () => refreshClipboardUrl(ref));
