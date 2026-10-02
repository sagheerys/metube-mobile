// Gathers transcripts for the clips a MeTube server downloaded before
// "Search inside clips" was turned on, into one file for Super's Import
// (Settings, Transcripts). The server is only read; subtitles come from yt-dlp here.
//
//   dart run packages/mt_transcripts/bin/backfill.dart \
//       --server http://192.168.1.10:8081 --languages ar,en
//
// Needs yt-dlp (with curl_cffi, or YouTube refuses the subtitles) and
// ffmpeg. Stopping it is safe: a second run resumes where it stopped.
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:mt_core/mt_core.dart';
import 'package:mt_transcripts/src/library_backfill.dart';
import 'package:mt_transcripts/src/yt_dlp_source.dart';

const _usage = '''
Options:
  --server URL        the MeTube server (required)
  --languages ar,en   languages to keep, as in the app (default: en)
  --translations      also ask for machine translations (often refused)
  --pause SECONDS     between two videos (default: 10)
  --limit N           fetch at most N videos this run
  --work DIR          answers kept between runs (default: .mtf-transcripts)
  --out FILE          the file to import (default: mtf-transcripts-library.json)
  --yt-dlp COMMAND    how to start yt-dlp (default: "python -m yt_dlp")
  --js-runtime NAME   JavaScript runtime for yt-dlp (default: node, "" for none)''';

Future<void> main(List<String> args) async {
  final options = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final name = args[i];
    if (!name.startsWith('--')) _fail('unexpected "$name"');
    if (name == '--translations') {
      options[name] = 'yes';
    } else if (i + 1 < args.length) {
      options[name] = args[++i];
    } else {
      _fail('$name needs a value');
    }
  }
  final server = options['--server'] ?? _fail('--server is required');
  final runtime = options['--js-runtime'] ?? 'node';
  final backfill = LibraryBackfill(
    source: YtDlpSource(
      command: (options['--yt-dlp'] ?? 'python -m yt_dlp').split(' '),
      extraArgs: runtime.isEmpty ? const [] : ['--js-runtimes', runtime],
    ),
    work: Directory(options['--work'] ?? '.mtf-transcripts'),
    languages: (options['--languages'] ?? 'en').split(','),
    translations: options.containsKey('--translations'),
    pause: Duration(seconds: int.parse(options['--pause'] ?? '10')),
    log: print,
  );

  final client = MeTubeApiClient(config: ServerConfig(baseUrl: server));
  final HistoryResponse history;
  try {
    history = await client.fetchHistory();
  } finally {
    client.close();
  }
  final clips = LibraryBackfill.candidates(history);
  print('${clips.length} YouTube clips on the server.');

  final limit = options['--limit'];
  final report = await backfill.run(
    clips,
    limit: limit == null ? null : int.parse(limit),
  );
  final out = File(options['--out'] ?? 'mtf-transcripts-library.json');
  await out.writeAsString(await backfill.bundle());

  print(
    '''

Saved now: ${report.saved} · already done: ${report.alreadyDone} · none offered: ${report.nothingOffered} · gone: ${report.gone} · failed: ${report.failed}''',
  );
  if (report.stoppedByRateLimit) {
    print('YouTube asked to slow down: run again later to go on.');
  }
  if (report.translationsRefused) {
    print(
      'Translations were refused part way; a later run with '
      '--translations tries them again.',
    );
  }
  print('Import ${out.absolute.path} in Super: Settings, Transcripts, Import.');
  exit(0);
}

Never _fail(String message) {
  stderr.writeln('$message\n$_usage');
  exit(64);
}
