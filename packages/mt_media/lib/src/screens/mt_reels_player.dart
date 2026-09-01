import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/playback_source.dart';
import '../models/playlist_item.dart';
import '../video/reels_overlay.dart';
import '../video/reels_stage.dart';
import '../video/shorts_lane.dart';
import 'mt_video_screen.dart';

/// **مشغل الريلز (م-35)** — غامر بسحب عمودي داخل «مسار القِصار» فقط:
/// القِصار العمودية من القائمة المعروضة بنفس ترتيبها، والصوتي والعرضي
/// يُتخطيان بصمت (العداد يعدّ القِصار وحدها).
///
/// المقطع **يتكرر** حتى السحب، ولا يُحفظ له موضع استئناف (قاعدة م-35).
/// نقرة = إيقاف/تشغيل · مزدوجة = مفضلة · عمود أفعال جانبي.
class MTReelsPlayer extends StatefulWidget {
  const MTReelsPlayer({
    super.key,
    required this.lane,
    required this.resolver,
    this.startIndex = 0,
    this.isFavorite,
    this.onToggleFavorite,
    this.actionsBuilder,
    this.subtitleBuilder,
    this.onContinueRest,
    this.onTakeAudioFocus,
  });

  final ShortsLane lane;
  final PlaybackSourceResolver resolver;
  final int startIndex;
  final bool Function(PlaylistItem item)? isFavorite;
  final void Function(PlaylistItem item)? onToggleFavorite;
  final List<MTPlayerAction> Function(PlaylistItem item)? actionsBuilder;
  final String Function(BuildContext context, PlaylistItem item)?
      subtitleBuilder;

  /// «متابعة بقية القائمة» — يفتح أول عنصر غير قصير في مشغله الصحيح.
  final VoidCallback? onContinueRest;

  /// يوقف مشغل الصوت الخلفي قبل أول تشغيل — وإلا اشتغل الصوت والريل معاً.
  final Future<void> Function()? onTakeAudioFocus;

  @override
  State<MTReelsPlayer> createState() => _MTReelsPlayerState();
}

class _MTReelsPlayerState extends State<MTReelsPlayer> {
  late final PageController _pages =
      PageController(initialPage: widget.startIndex);
  VideoPlayerController? _controller;
  late int _index = widget.startIndex;
  bool _endReached = false;
  bool _failed = false;

  /// **حارس السباق (خلل مصطاد على جهاز المالك 2026-09-01).** السحب أسرع
  /// من `initialize()` — سحبتان متتاليتان تبدآن تحميلين متوازيين، ويفوز
  /// آخر من ينتهي بـ `_controller` بينما **يبقى الأول حياً يشتغل صوتاً
  /// خلف الصورة الجديدة**. كل سحبة إضافية تضيف صوتاً ثالثاً ورابعاً.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    // **شريط الحالة يبقى مرئياً (بلاغ المالك 2026-09-02):** إنستقرام
    // وتيك توك يمدّان الفيديو خلف الشريط ولا يخفيانه — الساعة والبطارية
    // حق المستخدم، و`immersiveSticky` كان يبتلعهما ويجعل السحب من الحافة
    // يستدعي الشريط بدل تغيير المقطع.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(_index));
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // إعادة أيقونات النظام لما يقرره الثيم — الريلز وحده داكن دائماً.
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _controller?.dispose();
    _pages.dispose();
    super.dispose();
  }

  PlaylistItem? get _current =>
      _index >= 0 && _index < widget.lane.length ? widget.lane.items[_index] : null;

  Future<void> _load(int index) async {
    final generation = ++_generation;
    final item = index < widget.lane.length ? widget.lane.items[index] : null;
    final old = _controller;
    _controller = null;
    if (mounted) setState(() => _failed = false);
    // إسكاته أولاً: `dispose()` قد ينتظر، والصوت يستمر طوال الانتظار.
    await old?.pause();
    await old?.dispose();
    if (item == null) return;

    final source = widget.resolver.resolve(item);
    if (source == null) {
      if (mounted && generation == _generation) {
        setState(() => _failed = true);
      }
      return;
    }
    final controller = source.origin == PlaybackOrigin.local
        ? VideoPlayerController.file(File(source.uri.toFilePath()))
        : VideoPlayerController.networkUrl(source.uri,
            httpHeaders: source.headers);
    try {
      await controller.initialize();
    } on Object {
      await controller.dispose();
      if (mounted && generation == _generation) {
        setState(() => _failed = true);
      }
      return;
    }
    // سحبة أحدث سبقتنا ⇒ نتخلص من هذا المتحكم بدل أن نتركه يعمل.
    if (!mounted || generation != _generation) return controller.dispose();
    await controller.setLooping(true); // يتكرر حتى السحب (م-35)
    await widget.onTakeAudioFocus?.call();
    if (!mounted || generation != _generation) return controller.dispose();
    await controller.play();
    setState(() => _controller = controller);
  }

  void _onPageChanged(int page) {
    if (page >= widget.lane.length) {
      setState(() => _endReached = true);
      _controller?.pause();
      return;
    }
    setState(() {
      _index = page;
      _endReached = false;
    });
    _load(page);
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await widget.onTakeAudioFocus?.call();
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final item = _current;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pages,
            scrollDirection: Axis.vertical,
            // صفحة زائدة واحدة = بطاقة «انتهت القِصار» بعد ارتداد السحب.
            itemCount: widget.lane.length + 1,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, page) => page >= widget.lane.length
                ? const SizedBox.expand()
                : ReelsVideoLayer(
                    controller: page == _index ? _controller : null,
                    failed: page == _index && _failed,
                    onTap: _togglePlay,
                    onDoubleTap: () {
                      final target = widget.lane.items[page];
                      // م-36: الضغطة المزدوجة إيماءة عمياء — النبضة هي
                      // التأكيد الوحيد أن التبديل وقع فعلاً.
                      HapticFeedback.selectionClick();
                      widget.onToggleFavorite?.call(target);
                      setState(() {});
                    },
                  ),
          ),
          if (_endReached)
            MTReelsEndCard(
              onBack: () => Navigator.of(context).maybePop(),
              onContinueRest: widget.onContinueRest,
              onReplay: () {
                _pages.jumpToPage(0);
                _onPageChanged(0);
              },
            )
          else if (item != null)
            ReelsOverlayLayer(
              item: item,
              index: _index,
              total: widget.lane.length,
              favorite: widget.isFavorite?.call(item) ?? false,
              onToggleFavorite: () {
                widget.onToggleFavorite?.call(item);
                setState(() {});
              },
              actions: widget.actionsBuilder?.call(item) ?? const [],
              subtitle: widget.subtitleBuilder?.call(context, item),
              controller: _controller,
            ),
        ],
      ),
    );
  }
}
