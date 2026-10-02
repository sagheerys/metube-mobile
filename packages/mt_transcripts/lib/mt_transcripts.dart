/// Transcripts for Super: fetched from MeTube before the clip itself,
/// stored one file per clip, and searched in memory.
///
/// Super depends on this package and Lite does not, so Lite can never
/// reach any of it.
library;

export 'src/captions_fetcher.dart';
export 'src/search_text.dart';
export 'src/sidecar_miss_index.dart';
export 'src/sidecar_reader.dart';
export 'src/subtitle_parser.dart';
export 'src/transcript.dart';
export 'src/transcript_bundle.dart';
export 'src/transcript_index.dart';
export 'src/transcript_store.dart';
