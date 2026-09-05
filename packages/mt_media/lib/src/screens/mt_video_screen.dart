import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player/video_player.dart';

import '../models/playlist_item.dart';
import '../video/mt_orientation.dart';
import '../video/mt_video_controls.dart';
import '../video/mt_video_fullscreen.dart';
import '../video/mt_video_session.dart';
import '../widgets/mt_queue_panel.dart';
import '../widgets/mt_up_next_list.dart';
import 'video_info_sheet.dart';

/// فعل من أفعال المشغل العمودي (دون اتصال / مشاركة / لقائمة …) —
/// يقدّمها التطبيق لأن mt_media لا يعرف السيرفر ولا الفهارس.
class MTPlayerAction {
  const MTPlayerAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;
}

/// مشغل الفيديو العمودي (م-20 · مرجع «وهج» B): الفيديو يتصدر وتحته
/// ورقة كريمية — العنوان ← الأفعال ← الوضع ← قائمة «التالي».
/// الرجوع يعرض «متابعة صوتاً بالخلفية؟» من نفس الثانية (م-23).
class MTVideoScreen extends StatelessWidget {
  const MTVideoScreen({
    super.key,
    required this.session,
    this.actions = const [],
    this.artwork,
    this.subtitleBuilder,
    this.onShowPlaylist,
    this.onContinueAsAudio,
    this.shouldOfferContinueAsAudio,
    this.playlistName,
    this.membershipLine,
  });

  final MTVideoSession session;
  final List<MTPlayerAction> actions;
  final MTArtworkBuilder? artwork;

  /// سطر البيانات تحت العنوان (المنصة · الناشر) — من التطبيق.
  final String Function(BuildContext context, PlaylistItem item)?
      subtitleBuilder;
  final VoidCallback? onShowPlaylist;

  /// م-23: المزامنة الذكية — متابعة نفس العنصر صوتاً من نفس الثانية.
  /// **يُنتظر قبل إغلاق الشاشة (العطل ط-5):** كان يُستدعى بلا انتظار ثم
  /// يُغلق المشغل فوراً، فيُصرَّف مزوّد الجلسة (autoDispose) بينما النقل
  /// واقف على `await` — فإما `StateError` فلا يبدأ الصوت أصلاً، وإما
  /// تصير `duration` عدماً فيُحفظ موضع قرب النهاية **بدل مسحه** ويظل
  /// المقطع «يستأنف» عند الاعتمادات للأبد.
  final Future<void> Function(PlaylistItem item, Duration position)?
      onContinueAsAudio;

  /// **متى يُسأل السؤال** (بلاغ المالك 2026-09-02: «بعد المتابعة في
  /// الخلفية والضغط رجوع تظهر الرسالة، المفترض لا تظهر»). كان الشرط
  /// `onContinueAsAudio == null` وحده، أي يُسأل في كل خروج — حتى بعد أن
  /// يكون المستخدم قد نقل المقطع للصوت فعلاً. التطبيق وحده يعرف حالة
  /// مشغل الصوت، فهو من يقرر.
  final bool Function()? shouldOfferContinueAsAudio;
  final String? playlistName;

  /// **انتماء المقطع** (بلاغ المالك 2026-09-04): «في أي وسم يتبع أو في
  /// أي قائمة مضاف». يظهر في الوضع العرضي تحت العنوان — العمودي يعرضه
  /// عبر [subtitleBuilder] في ورقة المعلومات.
  final String? membershipLine;

  bool get _offersAudio =>
      onContinueAsAudio != null &&
      (shouldOfferContinueAsAudio?.call() ?? true);

  /// **الإمالة تفتح الملء التام والإمالة العكسية تغلقه** (قرار المالك
  /// 2026-09-05) — والزر يبقى لمن أقفل التدوير في نظامه.
  @override
  Widget build(BuildContext context) => MTRotationScope(
        open: (byRotation) => _openFullscreen(context, byRotation),
        builder: (context, openFullscreen) => _body(context, openFullscreen),
      );

  Widget _body(BuildContext context, VoidCallback openFullscreen) => PopScope(
        canPop: !_offersAudio,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _askContinueAsAudio(context);
        },
        child: Scaffold(
          // **شريط النظام يتبع الثيم** (بلاغ المالك 2026-09-05: «شريط
          // الساعة داكن نهاراً فيبدو غريباً»). الفيديو نفسه يبقى على
          // أرضية داكنة — لكن الشريط فوقه كان يأخذ لون الصفحة، وكانت
          // «داكنة دائماً» فيظهر نهاراً شريطٌ ليلي فوق واجهة كريمية.
          backgroundColor: MTThemeX.of(context).palette.bg,
          body: ListenableBuilder(
            listenable: session,
            // **عرضياً: الفيديو وحده يملأ الشاشة** (بلاغ المالك
            // 2026-09-05: «أخرج من الملء التام والجهاز عرضي فيظهر
            // التطبيق بالعرض»). الخروج اليدوي يُنزع تسليح الإمالة
            // فلا يُعاد فتح الملء التام — وكانت النتيجة ورقةً كريمية
            // وفيديو مضغوط في شاشة عريضة. الآن الوضع العرضي **شكلٌ**
            // من أشكال هذه الشاشة لا خطأً فيها.
            builder: (context, _) =>
                MediaQuery.orientationOf(context) == Orientation.landscape
                    ? _VideoArea(
                        session: session,
                        fill: true,
                        playlistName: playlistName,
                        membershipLine: membershipLine,
                        onBack: () => Navigator.of(context).maybePop(),
                        onFullscreen: openFullscreen,
                        onQueue: () => _openQueue(context),
                      )
                    : Column(
              children: [
                _VideoArea(
                  session: session,
                  playlistName: playlistName,
                  membershipLine: membershipLine,
                  onBack: () => Navigator.of(context).maybePop(),
                  onFullscreen: openFullscreen,
                  onQueue: () => _openQueue(context),
                ),
                Expanded(
                  child: MTVideoInfoSheet(
                    session: session,
                    actions: actions,
                    artwork: artwork,
                    subtitleBuilder: subtitleBuilder,
                    playlistName: playlistName,
                    onShowPlaylist: onShowPlaylist,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _openFullscreen(BuildContext context, bool byRotation) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MTVideoFullscreenPage(
            session: session,
            byRotation: byRotation,
            artwork: artwork,
            playlistName: playlistName,
            membershipLine: membershipLine,
            onShowPlaylist: onShowPlaylist,
          ),
        ),
      );

  void _openQueue(BuildContext context) {
    final ordered = session.orderedItems;
    final currentUrl = session.current?.canonicalUrl;
    showMTQueueSheet(
      context,
      items: ordered,
      currentIndex: ordered.indexWhere((i) => i.canonicalUrl == currentUrl),
      artwork: artwork,
      playlistName: playlistName,
      // الجلسة تُخطر عند كل نبضة، فالورقة تعرف متى توقّف التشغيل.
      liveness: session,
      paused: () => !session.isPlaying,
      onShowAll: onShowPlaylist,
      onSelect: (index) =>
          session.jumpTo(session.items.indexOf(ordered[index])),
    );
  }

  /// حوار المزامنة الذكية عند الخروج (م-23).
  Future<void> _askContinueAsAudio(BuildContext context) async {
    final item = session.current;
    final navigator = Navigator.of(context);
    // **لا نُسقط إلا صفحتنا** (بلاغ المالك 2026-09-03): النقل إلى الصوت
    // قد يطول، وقد يكون المستخدم غادر بطريق آخر خلاله — فـ`pop()` عمياء
    // بعده تُسقط **الغلاف نفسه** فلا يبقى شيء: شاشة سوداء.
    final route = ModalRoute.of(context);
    void popSelf() {
      if (route == null || route.isCurrent) navigator.pop();
    }

    if (item == null) return popSelf();
    final position = session.position;
    await session.savePosition();
    if (!context.mounted) return;
    final l10n = context.mtl;

    final choice = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.continueAsAudioTitle),
        content: Text(l10n.continueAsAudioBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.continueAsAudioNo),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.continueAsAudio),
          ),
        ],
      ),
    );
    if (choice == true) await onContinueAsAudio?.call(item, position);
    popSelf();
  }
}

class _VideoArea extends StatelessWidget {
  const _VideoArea({
    required this.session,
    required this.onBack,
    required this.onFullscreen,
    required this.onQueue,
    this.playlistName,
    this.membershipLine,
    this.fill = false,
  });

  /// يملأ الشاشة (الوضع العرضي) بدل 32٪ من ارتفاعها.
  final bool fill;

  final MTVideoSession session;
  final VoidCallback onBack;
  final VoidCallback onFullscreen;
  final VoidCallback onQueue;
  final String? playlistName;
  final String? membershipLine;

  @override
  Widget build(BuildContext context) {
    final controller = session.controller;
    final ready = controller != null && controller.value.isInitialized;
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: fill
            ? double.infinity
            : MediaQuery.sizeOf(context).height * 0.32,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: MTPalette.serverCardBg),
            if (ready)
              Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              )
            else
              Center(
                child: session.error != null
                    ? Icon(Icons.error_outline_rounded,
                        color: MTPalette.serverCardInk)
                    : const CircularProgressIndicator(),
              ),
            if (ready)
              MTVideoControls(
                session: session,
                playlistName: playlistName,
                membershipLine: membershipLine,
                onBack: onBack,
                onToggleFullscreen: onFullscreen,
                onQueue: onQueue,
              ),
          ],
        ),
      ),
    );
  }
}
