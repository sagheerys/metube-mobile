import 'dart:convert';
import 'dart:io';

import 'transcript.dart';

/// Where transcripts live: one JSON file per clip and language, in a folder
/// of their own.
///
/// **Files, not a database, are the record**: a search index can always be
/// rebuilt from them, and a folder of plain files is what an export copies
/// and an import restores.
///
/// **Nothing is created until the first write**, so a phone that never
/// turns the feature on never gets the folder at all.
class TranscriptStore {
  TranscriptStore(this.root);

  /// A folder the app owns, outside the cache: Android empties caches on
  /// its own, and a transcript fetched once should not have to be fetched
  /// again.
  final Directory root;

  File _file(String name) => File('${root.path}${Platform.pathSeparator}$name');

  /// A clip holds one file per language, named from both.
  static String _nameFor(String canonicalUrl, String language) =>
      _hashName('$canonicalUrl\n$language');

  /// The name a clip's only file had before a clip could hold two
  /// languages. Still read, and replaced on the next write.
  static String _legacyNameFor(String canonicalUrl) => _hashName(canonicalUrl);

  /// A stable name from text that holds characters no file system accepts.
  /// What the file holds is checked on read, so the rare collision reads
  /// as "no transcript", never as another clip's.
  static String _hashName(String key) {
    // 64-bit FNV-1a. Native integers wrap at 64 bits, which is the
    // arithmetic the algorithm expects.
    var hash = 0xcbf29ce484222325;
    for (final byte in utf8.encode(key)) {
      hash ^= byte;
      hash *= 0x100000001b3;
    }
    // Two unsigned halves: the integer itself is signed.
    String half(int v) => v.toRadixString(16).padLeft(8, '0');
    return '${half(hash >>> 32)}${half(hash & 0xFFFFFFFF)}.json';
  }

  Future<Transcript?> read(String canonicalUrl, String language) async {
    for (final name in [
      _nameFor(canonicalUrl, language),
      _legacyNameFor(canonicalUrl),
    ]) {
      final file = _file(name);
      if (!await file.exists()) continue;
      final transcript = _decode(await file.readAsString());
      if (transcript?.canonicalUrl == canonicalUrl &&
          transcript?.language == language) {
        return transcript;
      }
    }
    return null;
  }

  /// Every language kept for one clip.
  Future<List<Transcript>> readFor(String canonicalUrl) async => [
    await for (final t in readAll())
      if (t.canonicalUrl == canonicalUrl) t,
  ];

  /// Written to a temporary file and renamed, so a crash mid-write leaves
  /// the previous transcript whole rather than half of a new one.
  Future<void> write(Transcript transcript) async {
    await root.create(recursive: true);
    final url = transcript.canonicalUrl;
    final file = _file(_nameFor(url, transcript.language));
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(transcript.toJson()), flush: true);
    await temp.rename(file.path);
    // The same clip and language under the old name would now be read
    // twice.
    final legacy = _file(_legacyNameFor(url));
    if (await legacy.exists()) {
      final old = _decode(await legacy.readAsString());
      if (old?.canonicalUrl == url && old?.language == transcript.language) {
        await legacy.delete();
      }
    }
  }

  /// Removes every language kept for one clip.
  Future<void> remove(String canonicalUrl) async {
    if (!await root.exists()) return;
    await for (final entry in root.list()) {
      if (entry is! File || !entry.path.endsWith('.json')) continue;
      final transcript = _decode(await entry.readAsString());
      if (transcript?.canonicalUrl == canonicalUrl) await entry.delete();
    }
  }

  Future<bool> has(String canonicalUrl) async =>
      (await readFor(canonicalUrl)).isNotEmpty;

  /// Every readable transcript. A file this code cannot read (a newer
  /// format, a broken write) is skipped, not fatal.
  ///
  /// A file under the old one-per-clip name is dropped once the same clip
  /// and language exist under the new name: [write] only clears one that
  /// was labelled exactly as the new one, and the first version's labels
  /// were not always the language asked for.
  Stream<Transcript> readAll() async* {
    if (!await root.exists()) return;
    await for (final entry in root.list()) {
      if (entry is! File || !entry.path.endsWith('.json')) continue;
      final transcript = _decode(await entry.readAsString());
      if (transcript == null) continue;
      if (await _superseded(entry, transcript)) {
        await entry.delete();
        continue;
      }
      yield transcript;
    }
  }

  Future<bool> _superseded(File file, Transcript transcript) async {
    final url = transcript.canonicalUrl;
    final name = file.uri.pathSegments.last;
    if (name != _legacyNameFor(url)) return false;
    return _file(_nameFor(url, transcript.language)).exists();
  }

  /// The folder's size, for the settings line that tells the user what
  /// the feature costs in space.
  Future<int> sizeBytes() async {
    if (!await root.exists()) return 0;
    var total = 0;
    await for (final entry in root.list()) {
      if (entry is File) total += await entry.length();
    }
    return total;
  }

  /// Removes every transcript and the folder with them.
  Future<void> clear() async {
    if (await root.exists()) await root.delete(recursive: true);
  }

  static Transcript? _decode(String raw) {
    try {
      return Transcript.fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }
}
