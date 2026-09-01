import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player/video_player.dart';

import '../models/playback_source.dart';
import '../models/playlist_item.dart';
import '../video/reels_overlay.dart';
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

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(_index));
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller?.dispose();
    _pages.dispose();
    super.dispose();
  }

  PlaylistItem? get _current =>
      _index >= 0 && _index < widget.lane.length ? widget.lane.items[_index] : null;

  Future<void> _load(int index) async {
    final item = index < widget.lane.length ? widget.lane.items[index] : null;
    final old = _controller;
    _controller = null;
    if (mounted) setState(() => _failed = false);
    await old?.dispose();
    if (item == null) return;

    final source = widget.resolver.resolve(item);
    if (source == null) {
      if (mounted) setState(() => _failed = true);
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
      if (mounted) setState(() => _failed = true);
      return;
    }
    if (!mounted) return controller.dispose();
    await controller.setLooping(true); // يتكرر حتى السحب (م-35)
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

  void _togglePlay() {
    final controller = _controller;
    if (controller == null) return;
    setState(() => controller.value.isPlaying
        ? controller.pause()
        : controller.play());
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
                : _VideoLayer(
                    controller: page == _index ? _controller : null,
                    failed: page == _index && _failed,
                    onTap: _togglePlay,
                    onDoubleTap: () {
                      final target = widget.lane.items[page];
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
            _Overlay(
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

class _VideoLayer extends StatelessWidget {
  const _VideoLayer({
    required this.controller,
    required this.failed,
    required this.onTap,
    required this.onDoubleTap,
  });

  final VideoPlayerController? controller;
  final bool failed;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: failed
            ? Center(
                child: Text(context.mtl.playerError,
                    style: TextStyle(color: MTPalette.serverCardInk)),
              )
            : controller == null || !controller!.value.isInitialized
                ? const Center(child: CircularProgressIndicator())
                : FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: controller!.value.size.width,
                      height: controller!.value.size.height,
                      child: VideoPlayer(controller!),
                    ),
                  ),
      );
}

class _Overlay extends StatelessWidget {
  const _Overlay({
    required this.item,
    required this.index,
    required this.total,
    required this.favorite,
    required this.onToggleFavorite,
    required this.actions,
    this.subtitle,
    this.controller,
  });

  final PlaylistItem item;
  final int index;
  final int total;
  final bool favorite;
  final VoidCallback onToggleFavorite;
  final List<MTPlayerAction> actions;
  final String? subtitle;
  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    return IgnorePointer(
      ignoring: false,
      child: Stack(
        children: [
          Positioned.fill(child: _Gradient()),
          PositionedDirectional(
            top: MTSpace.sm,
            start: MTSpace.xs,
            end: MTSpace.xs,
            child: SafeArea(
              child: MTReelsTopBar(
                position: index + 1,
                total: total,
                onBack: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          PositionedDirectional(
            top: 64,
            start: 0,
            end: 0,
            child: Center(
              child: Text(
                '⌃ ${l10n.reelsSwipeHint}',
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                    color: MTPalette.serverCardInk.withValues(alpha: 0.45)),
              ),
            ),
          ),
          PositionedDirectional(
            start: MTSpace.md,
            bottom: 120,
            child: MTReelsRail(
              favorite: favorite,
              onToggleFavorite: onToggleFavorite,
              actions: actions,
            ),
          ),
          PositionedDirectional(
            start: 74,
            end: MTSpace.lg,
            bottom: MTSpace.xxl,
            child: MTReelsInfo(item: item, subtitle: subtitle),
          ),
          PositionedDirectional(
            start: MTSpace.lg,
            end: MTSpace.lg,
            bottom: MTSpace.sm,
            child: _Progress(controller: controller),
          ),
        ],
      ),
    );
  }
}

class _Gradient extends StatelessWidget {
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.45),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withValues(alpha: 0.6),
              ],
              stops: const [0, 0.22, 0.55, 1],
            ),
          ),
        ),
      );
}

class _Progress extends StatelessWidget {
  const _Progress({this.controller});

  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final value = controller;
    if (value == null || !value.value.isInitialized) {
      return const SizedBox(height: 3);
    }
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: value,
      builder: (context, state, _) {
        final total = state.duration.inMilliseconds;
        return ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: total <= 0
                ? 0
                : (state.position.inMilliseconds / total).clamp(0, 1),
            minHeight: 3,
            backgroundColor:
                MTPalette.serverCardInk.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation(p.accent),
          ),
        );
      },
    );
  }
}
