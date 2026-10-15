import 'dart:convert';

import 'package:mt_core/mt_core.dart';

/// The language a YouTube clip is spoken in, or null when it cannot be
/// told.
///
/// Read from the clip's page, where YouTube lists its subtitle tracks: the
/// one made by speech recognition (`"kind":"asr"`) is in the language
/// actually spoken. That is what makes the original-language subtitles
/// reachable at all: the server accepts a language code, not a pattern, and
/// the original track is named after its language (`es-orig`), so the
/// language has to be known before asking.
///
/// The page is fetched straight from YouTube, never through the server
/// client, so the server's credentials cannot travel with it. Any failure
/// is a null: the clip simply keeps the app's own languages.
Future<String?> youtubeSpokenLanguage(
  String videoId, {
  HttpGetString get = ioHttpGetString,
  Duration timeout = const Duration(seconds: 6),
}) async {
  try {
    final page = await get(
      Uri.https('www.youtube.com', '/watch', {'v': videoId}),
    ).timeout(timeout);
    return spokenLanguageIn(page);
  } on Object {
    return null;
  }
}

/// The speech-recognised track's language in a watch page.
String? spokenLanguageIn(String page) {
  final tracks = _array(page, '"captionTracks":');
  if (tracks == null) return null;
  final decoded = jsonDecode(tracks);
  if (decoded is! List) return null;
  for (final track in decoded) {
    if (track is Map && track['kind'] == 'asr') {
      final code = track['languageCode'];
      if (code is String && RegExp(r'^[A-Za-z]{2,3}$').hasMatch(code)) {
        return code.toLowerCase();
      }
    }
  }
  return null;
}

/// The JSON array right after [key], found by counting brackets outside
/// strings: a track's name holds arrays of its own, so the first `]` is not
/// the end.
String? _array(String text, String key) {
  final at = text.indexOf(key);
  if (at < 0) return null;
  final start = text.indexOf('[', at + key.length);
  if (start < 0) return null;
  var depth = 0;
  var inString = false;
  for (var i = start; i < text.length; i++) {
    final c = text[i];
    if (inString) {
      if (c == r'\') {
        i++;
      } else if (c == '"') {
        inString = false;
      }
    } else if (c == '"') {
      inString = true;
    } else if (c == '[') {
      depth++;
    } else if (c == ']' && --depth == 0) {
      return text.substring(start, i + 1);
    }
  }
  return null;
}
