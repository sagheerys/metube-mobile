import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../models/media_quality.dart';

/// A details row as each app's sheet draws it: label, then value.
typedef MTDetailsRowBuilder = Widget Function(String label, String value);

/// **The video and audio quality in the details sheet** (asked
/// 2026-09-25), from the file's own header — see [MediaQuality].
///
/// Read once per clip per run: the answer does not change, and a stream's
/// header costs a request. Until it arrives the rows say so; if it never
/// does (server down, a format the platform cannot parse) they say it is
/// unavailable rather than vanish, so the sheet does not jump.
class MTQualityRows extends StatefulWidget {
  const MTQualityRows({
    super.key,
    required this.cacheKey,
    required this.load,
    required this.row,
    this.sizeBytes,
    this.duration,
  });

  /// The clip's canonical URL: what the answer is remembered under.
  final String cacheKey;
  final Future<MediaQuality?> Function() load;
  final MTDetailsRowBuilder row;

  /// With [duration], gives the average bitrate — the one number that
  /// says how much quality a file carries, whatever its codec.
  final int? sizeBytes;
  final Duration? duration;

  /// This run's answers. A failure is not remembered, so the next opening
  /// tries again.
  static final Map<String, MediaQuality> _known = {};

  @visibleForTesting
  static void forgetAll() => _known.clear();

  @override
  State<MTQualityRows> createState() => _MTQualityRowsState();
}

class _MTQualityRowsState extends State<MTQualityRows> {
  MediaQuality? _quality;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final known = MTQualityRows._known[widget.cacheKey];
    if (known != null) {
      _quality = known;
      _done = true;
    } else {
      _read();
    }
  }

  Future<void> _read() async {
    MediaQuality? quality;
    try {
      quality = await widget.load();
    } on Object {
      quality = null;
    }
    if (quality != null && !quality.isEmpty) {
      MTQualityRows._known[widget.cacheKey] = quality;
    }
    if (mounted) {
      setState(() {
        _quality = quality;
        _done = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final quality = _quality;
    if (!_done) return widget.row(l10n.qualityVideo, l10n.qualityReading);
    if (quality == null || quality.isEmpty) {
      return widget.row(l10n.qualityVideo, l10n.qualityUnavailable);
    }
    final bitrate = _bitrate(l10n);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (quality.hasVideo)
          widget.row(
            l10n.qualityVideo,
            mtMetaLine([
              quality.resolutionLabel,
              if (quality.width != null && quality.height != null)
                '${quality.width}×${quality.height}',
              quality.videoCodec,
              if (quality.frameRate != null)
                l10n.framesPerSecond(quality.frameRate!),
              bitrate,
            ]),
          ),
        if (quality.hasAudio)
          widget.row(
            l10n.qualityAudio,
            mtMetaLine([
              quality.audioCodec,
              switch (quality.channels) {
                1 => l10n.audioMono,
                2 => l10n.audioStereo,
                final int n => l10n.audioChannels(n),
                null => null,
              },
              // An audio-only file's average is its audio bitrate.
              if (!quality.hasVideo) bitrate,
            ]),
          ),
      ],
    );
  }

  /// Size over duration: exact for the file, an average over its length.
  String? _bitrate(MTLocalizations l10n) {
    final bytes = widget.sizeBytes;
    final seconds = (widget.duration?.inMilliseconds ?? 0) / 1000;
    if (bytes == null || bytes <= 0 || seconds <= 0) return null;
    final kbps = bytes * 8 / seconds / 1000;
    return kbps >= 1000
        ? l10n.bitrateMbps((kbps / 1000).toStringAsFixed(1))
        : l10n.bitrateKbps(kbps.round().toString());
  }
}
