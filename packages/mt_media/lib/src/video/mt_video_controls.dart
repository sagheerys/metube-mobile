import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import 'mt_video_session.dart';
import 'video_buttons.dart';
import 'video_control_bars.dart';

/// أدوات الفيديو فوق المقطع (مرجع «وهج» C): لمسة تُظهرها و٣ ثوانٍ
/// تخفيها، نقرة مزدوجة يمين/يسار = ±١٠ ثوانٍ، وقفل لمس في الوضع الغامر.
class MTVideoControls extends StatefulWidget {
  const MTVideoControls({
    super.key,
    required this.session,
    required this.onBack,
    required this.onToggleFullscreen,
    required this.onQueue,
    this.fullscreen = false,
    this.playlistName,
    this.membershipLine,
  });

  final MTVideoSession session;
  final VoidCallback onBack;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onQueue;
  final bool fullscreen;
  final String? playlistName;
  final String? membershipLine;

  @override
  State<MTVideoControls> createState() => _MTVideoControlsState();
}

class _MTVideoControlsState extends State<MTVideoControls> {
  static const Duration _hideAfter = Duration(seconds: 3);

  bool _visible = true;
  bool _locked = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _restartTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideAfter, () {
      if (mounted && widget.session.isPlaying) setState(() => _visible = false);
    });
  }

  void _toggleVisible() {
    setState(() => _visible = !_visible);
    if (_visible) _restartTimer();
  }

  void _onDoubleTap(TapDownDetails details, BoxConstraints constraints) {
    if (_locked) return;
    final isStart = details.localPosition.dx < constraints.maxWidth / 2;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final backward = rtl ? !isStart : isStart;
    widget.session.seekBy(Duration(seconds: backward ? -10 : 10));
    _restartTimer();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleVisible,
          onDoubleTapDown: (d) => _onDoubleTap(d, constraints),
          onDoubleTap: () {},
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: MTMotion.fast,
            curve: MTMotion.ease,
            child: IgnorePointer(
              ignoring: !_visible,
              child: _locked ? _lockedLayer() : _controlsLayer(),
            ),
          ),
        ),
      );

  Widget _lockedLayer() => Center(
        child: MTVideoIconButton(
          icon: Icons.lock_open_rounded,
          tooltip: context.mtl.unlockTouch,
          onTap: () {
            setState(() => _locked = false);
            _restartTimer();
          },
        ),
      );

  Widget _controlsLayer() => Stack(
        children: [
          const Positioned.fill(child: _Scrim()),
          PositionedDirectional(
            top: MTSpace.sm,
            start: MTSpace.md,
            end: MTSpace.md,
            child: MTVideoTopBar(
              session: widget.session,
              onBack: widget.onBack,
              onToggleFullscreen: widget.onToggleFullscreen,
              fullscreen: widget.fullscreen,
              playlistName: widget.playlistName,
              membershipLine: widget.membershipLine,
              onLock: widget.fullscreen
                  ? () {
                      _hideTimer?.cancel();
                      setState(() => _locked = true);
                    }
                  : null,
            ),
          ),
          Positioned.fill(
            child: Center(
              child: MTVideoCenterControls(session: widget.session),
            ),
          ),
          PositionedDirectional(
            // فوق الحافة المدورة للورقة الكريمية التي تعلو الفيديو 14px.
            bottom: widget.fullscreen ? MTSpace.xs : MTSpace.xl,
            start: MTSpace.md,
            end: MTSpace.md,
            child: MTVideoBottomBar(
              session: widget.session,
              onQueue: widget.onQueue,
            ),
          ),
        ],
      );
}

/// تدرّج علوي وسفلي يفصل الأدوات عن الصورة (من المرجع).
class _Scrim extends StatelessWidget {
  const _Scrim();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.5),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withValues(alpha: 0.6),
            ],
            stops: const [0, 0.28, 0.6, 1],
          ),
        ),
      );
}
