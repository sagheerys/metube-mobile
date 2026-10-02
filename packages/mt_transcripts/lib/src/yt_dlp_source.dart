import 'dart:convert';
import 'dart:io';

import 'subtitle_source.dart';

/// Subtitles fetched by yt-dlp on the computer running it.
///
/// Two runs per video: one reads what the video offers, the next fetches
/// the chosen tracks from that same reading (`--load-info-json`), so the
/// video page is asked for once. Translations go in a run of their own:
/// YouTube refuses them far sooner, and that refusal must not cost the
/// video's own tracks.
class YtDlpSource implements SubtitleSource {
  YtDlpSource({
    this.command = const ['python', '-m', 'yt_dlp'],
    this.extraArgs = const ['--js-runtimes', 'node'],
  });

  /// How yt-dlp is started here.
  final List<String> command;

  /// Passed to every run: YouTube now needs a JavaScript runtime to read
  /// a video page in full.
  final List<String> extraArgs;

  @override
  Future<FetchedTracks> fetch(
    String url,
    List<TrackChoice> Function(OfferedTracks offered) choose,
  ) async {
    final dir = await Directory.systemTemp.createTemp('mtf-subs-');
    try {
      final base = '${dir.path}${Platform.pathSeparator}v';
      await _run([
        '--skip-download',
        '--write-info-json',
        '--no-playlist',
        '-o',
        '$base.%(ext)s',
        url,
      ]);
      final info = jsonDecode(await File('$base.info.json').readAsString());
      final choices = choose(offeredIn(info));

      final own = [
        for (final c in choices)
          if (c.kind != TrackKind.translated) c.track,
      ];
      final translated = [
        for (final c in choices)
          if (c.kind == TrackKind.translated) c.track,
      ];
      final texts = <String, String>{};
      if (own.isNotEmpty) texts.addAll(await _download(base, own));
      var refused = false;
      if (translated.isNotEmpty) {
        try {
          texts.addAll(await _download(base, translated));
        } on BackfillRateLimited {
          refused = true;
        }
      }
      return FetchedTracks(texts, translationsRefused: refused);
    } finally {
      await dir.delete(recursive: true);
    }
  }

  Future<Map<String, String>> _download(
    String base,
    List<String> tracks,
  ) async {
    await _run([
      '--load-info-json',
      '$base.info.json',
      '--skip-download',
      '--write-subs',
      '--write-auto-subs',
      '--sub-langs',
      tracks.join(','),
      '--convert-subs',
      'srt',
      '-o',
      '$base.%(ext)s',
    ]);
    return {
      for (final track in tracks)
        if (File('$base.$track.srt') case final file when file.existsSync())
          track: await file.readAsString(),
    };
  }

  Future<void> _run(List<String> args) async {
    final result = await Process.run(
      command.first,
      [
        ...command.skip(1),
        '--ignore-config',
        '--no-progress',
        ...extraArgs,
        ...args,
      ],
      // Titles in any script reach a console that may not be UTF-8.
      environment: const {'PYTHONUTF8': '1', 'PYTHONIOENCODING': 'utf-8'},
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (result.exitCode != 0) throw classify('${result.stderr}');
  }

  /// The subtitle tracks named in a yt-dlp info file.
  static OfferedTracks offeredIn(Object? info) {
    Set<String> keys(Object? tracks) =>
        tracks is Map ? {for (final k in tracks.keys) '$k'} : <String>{};
    return info is Map
        ? OfferedTracks(
            written: keys(info['subtitles'])..remove('live_chat'),
            automatic: keys(info['automatic_captions']),
          )
        : const OfferedTracks();
  }

  static final _blocked = RegExp(
    r'HTTP Error 429|Too Many Requests|not a bot',
    caseSensitive: false,
  );
  static final _gone = RegExp(
    r'Video unavailable|Private video|has been removed|members-only|'
    r'account .* terminated|video is not available',
    caseSensitive: false,
  );

  /// What a failed run's error output means for the backfill.
  static Exception classify(String stderr) {
    final errors = stderr
        .split('\n')
        .where((line) => line.startsWith('ERROR:'))
        .join('\n');
    final text = (errors.isEmpty ? stderr : errors).trim();
    if (_blocked.hasMatch(text)) return BackfillRateLimited(text);
    if (_gone.hasMatch(text)) return VideoGone(text);
    return FetchFailed(text);
  }
}
