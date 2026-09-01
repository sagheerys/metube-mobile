import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../home/add_flow.dart';
import '../home/reception.dart';

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
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(clipboardRefresherProvider)();
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

    return Scaffold(
      body: widget.navigationShell,
      floatingActionButton: branch == 2
          ? null
          : MTFab(
              label: clipboardUrl == null
                  ? l10n.addLinkFab
                  : l10n.clipboardLinkReady,
              highlighted: clipboardUrl != null,
              onPressed: _onFabPressed,
            ),
      bottomNavigationBar: NavigationBar(
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
      ),
    );
  }
}

/// دالة فحص الحافظة قابلة للاستدعاء من الغلاف.
final clipboardRefresherProvider =
    Provider<Future<void> Function()>((ref) => () => refreshClipboardUrl(ref));
