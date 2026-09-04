import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../home/add_flow.dart';
import '../home/app_shortcuts.dart';
import '../home/network_gate.dart';
import '../home/quick_download.dart';
import '../home/reception.dart';
import '../library/library_enricher.dart';
import '../library/library_models.dart' show MediaTypeFilter;
import '../library/library_providers.dart'
    show completionGlowProvider, libraryViewProvider;
import '../player/playback_providers.dart';
import '../shared/notification_permission.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shareReceiver = ShareReceiver(onUrls: _onSharedUrls);
    _shareReceiver!.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(clipboardRefresherProvider)();
      // م-21: إحياء جلسة الصوت المحفوظة (بلا تشغيل تلقائي) بعد أن يضبط
      // playbackWiringProvider رابط السيرفر الحالي.
      ref.read(playbackWiringProvider);
      ref.read(audioHandlerProvider).restoreSession();
      // 33+: بلا هذا الطلب لا يظهر إشعار الوسائط إطلاقاً (خلل مصطاد).
      const NotificationPermission().request();
      unawaited(_handleShortcut());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(clipboardRefresherProvider)();
      // الاختصار يصل كنيّة جديدة على تطبيق يعمل — لا إقلاع جديد.
      unawaited(_handleShortcut());
    }
  }

  /// م-41: تنفيذ اختصار الأيقونة. **الحافظة تُقرأ الآن لا من الحالة
  /// المحفوظة**: المستخدم نسخ الرابط ثم ضغط الأيقونة مباشرة، ولقطة
  /// `clipboardUrlProvider` قد تسبق النسخ بثوانٍ.
  Future<void> _handleShortcut() async {
    final shortcut = await const AppShortcuts().consume();
    if (shortcut == null || !mounted) return;
    switch (shortcut) {
      case AppShortcut.paste:
        await ref.read(clipboardRefresherProvider)();
        if (!mounted) return;
        final url = ref.read(clipboardUrlProvider);
        widget.navigationShell.goBranch(0);
        if (url == null) {
          openAddSheet(context, ref);
        } else if (startQuickDownload(context, ref, url)) {
          ref.read(clipboardUrlProvider.notifier).state = null;
        } else {
          openAddSheet(context, ref, initialUrl: url);
        }
      case AppShortcut.shorts:
        widget.navigationShell.goBranch(0);
        ref.read(libraryViewProvider.notifier).setType(MediaTypeFilter.shorts);
      case AppShortcut.audio:
        widget.navigationShell.goBranch(0);
        ref.read(libraryViewProvider.notifier).setType(MediaTypeFilter.audio);
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
      // **رابط قائمة صريح ⇒ شاشة الدفعي مباشرة** (م-5). مشاركة ألبوم
      // واحد كانت تفتح ورقة «إضافة رابط» — الشرط كان في مسار الروابط
      // المتعددة وحده. `watch?v=…&list=…` يبقى على سلوكه: هو فيديو
      // مفرد بالدرجة الأولى، ويوتيوب يُلحق `list` بمشاركاته كثيراً.
      if (_isPurePlaylistLink(urls.first)) {
        GoRouter.of(context).push('/batch', extra: urls.first);
        return;
      }
      // «التحميل السريع» يجعل الجودة الافتراضية إعداداً فاعلاً: الرابط
      // المشارَك ينزل فوراً بلا ورقة، والشريط يتيح التراجع. البوابة
      // داخل `startQuickDownload` نفسها فلا تُكرَّر هنا.
      if (startQuickDownload(context, ref, urls.first)) return;
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


  /// قائمة **بذاتها** لا فيديو داخل قائمة.
  static bool _isPurePlaylistLink(String url) =>
      PlaylistDetector.isPlaylist(url) && UrlKit.youtubeVideoId(url) == null;

  /// م-2: رابط جاهز بالحافظة ⇒ تنفيذ مباشر عند الضغط.
  void _onFabPressed() {
    final clipboardUrl = ref.read(clipboardUrlProvider);
    if (clipboardUrl != null) {
      if (startQuickDownload(context, ref, clipboardUrl)) {
        ref.read(clipboardUrlProvider.notifier).state = null;
        return;
      }
      openAddSheet(context, ref, initialUrl: clipboardUrl);
      return;
    }
    openAddSheet(context, ref);
  }

  /// شريط الحافظة: **يُطوى ولا يعود** لنفس الرابط في هذه الجلسة.
  void _dismissClipboard() {
    _dismissedClipboardUrl = ref.read(clipboardUrlProvider);
    setState(() {});
  }

  String? _dismissedClipboardUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final branch = widget.navigationShell.currentIndex;
    final clipboardUrl = ref.watch(clipboardUrlProvider);

    // يبقى محقونًا حياً ليتابع تغيّر إعدادات السيرفر أثناء التشغيل.
    ref.watch(playbackWiringProvider);
    // م-18/م-35: أغلفة وأبعاد عناصر المكتبة — يعيش بعمر التطبيق كي لا
    // يتوقف السبر عند مغادرة شاشة المكتبة.
    ref.watch(libraryEnrichmentProvider);
    // توهج العنصر المكتمل — يراقب من الغلاف كي لا يفوته اكتمال وقع
    // والمستخدم في شاشة أخرى.
    ref.watch(completionGlowProvider);
    // م-43: يستمع لعودة الشبكة فيعيد ما فشل بسببها.
    ref.watch(autoRetryProvider);
    ref.watch(batchDropWatcherProvider);

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
          // **شريط الحافظة**: تغيير عنوان الزر العائم وحده كان إشارة
          // خافتة جداً — الرابط نفسه لا يُرى، ولا سبيل لفتح الخيارات
          // بدل التحميل الفوري. الشريط يعرض الرابط ويقدّم الفعلين معاً.
          if (branch != 2 &&
              clipboardUrl != null &&
              clipboardUrl != _dismissedClipboardUrl)
            MTClipboardBanner(
              url: clipboardUrl,
              title: l10n.clipboardFound,
              downloadLabel: l10n.downloadNow,
              optionsLabel: l10n.chooseOptions,
              onDownload: () {
                // زر صريح مكتوب عليه «حمّل الآن» وبجانبه «اختر
                // الخيارات» — لا يمرّ ببوابة الإعداد.
                if (startQuickDownload(context, ref, clipboardUrl,
                    explicit: true)) {
                  ref.read(clipboardUrlProvider.notifier).state = null;
                } else {
                  openAddSheet(context, ref, initialUrl: clipboardUrl);
                }
              },
              onOptions: () =>
                  openAddSheet(context, ref, initialUrl: clipboardUrl),
              onDismiss: _dismissClipboard,
            ),
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
            icon: const Icon(Icons.video_library_outlined),
            selectedIcon: const Icon(Icons.video_library_rounded),
            label: l10n.navLibrary,
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
