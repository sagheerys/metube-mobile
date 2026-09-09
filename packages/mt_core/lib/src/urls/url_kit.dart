import '../constants/mt_constants.dart';

/// Pure URL tools with no network: extraction from shared text,
/// YouTube and numeric ids, normalisation, fuzzy matching, and the server
/// filename guard. Reference: the PRD plus `05-DATA-SCHEMA.md` §2.3.
abstract final class UrlKit {
  static final RegExp _urlPattern = RegExp(
    r'https?://[^\s<>"]+',
    caseSensitive: false,
  );

  /// A YouTube id (11 characters): watch, embed, v, shorts, live, youtu.be.
  static final RegExp _youtubeIdPattern = RegExp(
    r'(?:youtu\.be/|youtube\.com/(?:watch\?v=|embed/|v/|shorts/|live/))'
    r'([a-zA-Z0-9_-]{11})',
  );
  static final RegExp _youtubeQueryIdPattern = RegExp(
    r'[?&]v=([a-zA-Z0-9_-]{11})',
  );

  /// Strips the URL out of the text wrapped around it, such as a SoundCloud
  /// share that is a whole sentence plus the link. Returns the input
  /// unchanged when no URL is found, so validation can report it.
  static String extractUrl(String input) {
    final trimmed = _stripBidiMarks(input).trim();
    if (trimmed.isEmpty) return trimmed;
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      final spaceIdx = trimmed.indexOf(RegExp(r'\s'));
      return _stripTrailingPunctuation(
        spaceIdx < 0 ? trimmed : trimmed.substring(0, spaceIdx),
      );
    }
    final match = _urlPattern.firstMatch(trimmed);
    return match == null ? trimmed : _stripTrailingPunctuation(match.group(0)!);
  }

  /// Every URL in a piece of text, for sharing several links at once.
  static List<String> extractAllUrls(String input) =>
      _urlPattern.allMatches(_stripBidiMarks(input))
          .map((m) => _stripTrailingPunctuation(m.group(0)!))
          .toList();

  /// Direction marks and zero-width spaces, which **WhatsApp and Telegram
  /// wrap around links inside Arabic messages** (defect خ-5). Without
  /// removing them the URL reaches yt-dlp with an invisible tail and fails
  /// with an opaque server error, while the same link works when pasted by
  /// hand. This is an Arabic-first app.
  static final RegExp _bidiMarks = RegExp(
    '[\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]',
  );

  static String _stripBidiMarks(String input) =>
      input.replaceAll(_bidiMarks, '');

  /// Cleans the trailing punctuation messaging apps stick to the end of a
  /// link.
  static String _stripTrailingPunctuation(String url) =>
      url.replaceFirst(RegExp(r'''[)\]}>.,;:!?'"،؛]+$'''), '');

  /// The YouTube video id, or null for anything else.
  static String? youtubeVideoId(String url) {
    final byPath = _youtubeIdPattern.firstMatch(url)?.group(1);
    if (byPath != null) return byPath;
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      return _youtubeQueryIdPattern.firstMatch(url)?.group(1);
    }
    return null;
  }

  /// The longest numeric id of at least 10 digits in the path **or the
  /// query
  /// string**, or '' when there is none.
  ///
  /// **`=` alongside `/` (defect found 2026-09-08):** Facebook puts the id
  /// in the query rather than the path
  /// (`m.facebook.com/watch/?v=1619243166301797`), so this came back empty
  /// for all of its links, and matching fell through to the normalisation
  /// rank, which strips the query and flattens every `facebook.com/watch`
  /// into one.
  static String longestNumericId(String url) {
    final matches = RegExp(r'[/=](\d{10,})').allMatches(url);
    if (matches.isEmpty) return '';
    return matches
        .map((m) => m.group(1)!)
        .reduce((a, b) => a.length >= b.length ? a : b);
  }

  /// Normalisation for matching: drop the scheme, `www./m./on.`, the query
  /// and the trailing slash.
  static String normalize(String url) {
    var u = url.trim().toLowerCase();
    u = u.replaceFirst(RegExp(r'^https?://'), '');
    u = u.replaceFirst(RegExp(r'^(www\.|m\.|on\.)'), '');
    u = u.replaceFirst(RegExp(r'[?#].*$'), '');
    u = u.replaceFirst(RegExp(r'/+$'), '');
    return u;
  }

  /// Fuzzy matching between the entered URL and the canonical `/history`
  /// one. The ladder: exact, YouTube id, numeric id, normalisation, path
  /// prefix.
  ///
  /// **A decisive rule (caught against a real server 2026-09-01):** two
  /// YouTube ids are final references. When both exist and differ there is
  /// never a match, and watch URLs are not allowed to fall through to the
  /// normalisation rank, which strips the query and flattens every
  /// `youtube.com/watch` into one. That nearly deleted an innocent item.
  ///
  /// **And a second rule of equal weight (defect ح-2, 2026-09-02):** raw
  /// containment matched **the wrong item** for everything except YouTube:
  /// `soundcloud.com/x/track` matched `soundcloud.com/x/track-remix`, and a
  /// numeric id matched a longer number starting with it. The result was
  /// pulling an innocent file under the requested name **and deleting it
  /// from the server** in Lite. Containment is now **bounded**: a number is
  /// not accepted when glued to another number, and a path is accepted only
  /// as a complete prefix at a `/` boundary, so a private link like
  /// `…/track/s-abc123` still matches.
  static bool urlsMatch(String url1, String url2) {
    if (url1.isEmpty || url2.isEmpty) return false;
    if (url1 == url2) return true;

    final id1 = youtubeVideoId(url1) ?? '';
    final id2 = youtubeVideoId(url2) ?? '';
    if (id1.isNotEmpty && id2.isNotEmpty) return id1 == id2;
    if (id1.isNotEmpty && url2.contains(id1)) return true;
    if (id2.isNotEmpty && url1.contains(id2)) return true;
    // When only one URL has a YouTube id and the other has none, we do not
    // continue to the lenient normalisation ranks, because of the
    // flattening
    // risk on the shared watch path.
    if (id1.isNotEmpty || id2.isNotEmpty) return false;

    final numId1 = longestNumericId(url1);
    final numId2 = longestNumericId(url2);
    if (numId1.isNotEmpty && numId2.isNotEmpty) return numId1 == numId2;
    if (numId1.isNotEmpty) return _containsIdAtBoundary(url2, numId1);
    if (numId2.isNotEmpty) return _containsIdAtBoundary(url1, numId2);

    // **Two different query strings do not fall through to normalisation**
    // (defect found 2026-09-08): normalisation strips the query, and a
    // platform carrying identity in it (Facebook's `?v=…`) collapses
    // entirely
    // onto one path, `facebook.com/watch`, so **every clip matches every
    // other clip**. The effect was measured: one item made available
    // offline
    // gave its file to every other Facebook item, and `/history` matching
    // in
    // Lite pulled an innocent file **and then deleted the original from the
    // server**. This is the same rule written above for YouTube,
    // generalised
    // to every platform.
    final query1 = _queryOf(url1);
    final query2 = _queryOf(url2);
    if (query1.isNotEmpty && query2.isNotEmpty && query1 != query2) {
      return false;
    }

    final norm1 = normalize(url1);
    final norm2 = normalize(url2);
    if (norm1 == norm2) return true;
    return _isPathPrefix(norm1, norm2) || _isPathPrefix(norm2, norm1);
  }

  /// The query string alone, without the `#fragment`, or '' when absent.
  static String _queryOf(String url) {
    final at = url.indexOf('?');
    if (at < 0) return '';
    final rest = url.substring(at + 1);
    final hash = rest.indexOf('#');
    return (hash < 0 ? rest : rest.substring(0, hash)).toLowerCase();
  }

  /// Does [url] contain the number [id] **not glued to another number**?
  /// (`…/769798712` is not `…/76979871`.)
  static bool _containsIdAtBoundary(String url, String id) {
    var from = 0;
    while (true) {
      final at = url.indexOf(id, from);
      if (at < 0) return false;
      final before = at == 0 ? '' : url[at - 1];
      final afterIdx = at + id.length;
      final after = afterIdx >= url.length ? '' : url[afterIdx];
      if (!_isDigit(before) && !_isDigit(after)) return true;
      from = at + 1;
    }
  }

  static bool _isDigit(String ch) {
    if (ch.length != 1) return false;
    final code = ch.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }

  /// Is [shorter] a complete path prefix of [longer] at a `/` boundary?
  /// Accepts `a/b` against `a/b/s-token` and rejects `a/b` against
  /// `a/b-remix`.
  static bool _isPathPrefix(String longer, String shorter) =>
      shorter.isNotEmpty && longer.startsWith('$shorter/');

  /// The path-traversal guard for filenames coming from the server, applied
  /// before building a `/download/<filename>` URL. It rejects the empty
  /// string, path separators, the components `.` and `..` on their own, and
  /// the NUL character.
  ///
  /// **`..` inside a name is not traversal** (field report 2026-09-03). The
  /// condition used to be `contains('..')`, and yt-dlp truncates long
  /// titles
  /// with dots, so **every clip with a long title failed** with "unsafe
  /// filename" even though the server served it happily. Measured against a
  /// real Lite server: a truncated name with an embedded `...` returned
  /// **HTTP 206 video/mp4**. Traversal needs a path separator, which is
  /// rejected anyway.
  static bool isSafeServerFilename(String name) {
    if (name.isEmpty) return false;
    if (name == '.' || name == '..') return false;
    if (name.contains('/') || name.contains('\\')) return false;
    if (name.contains('\u0000')) return false;
    return true;
  }

  /// Is this a short link that needs redirect resolution?
  /// (`05-DATA-SCHEMA.md` §4.)
  static bool needsResolution(String url) {
    final u = url.toLowerCase();
    return u.contains('vt.tiktok.com') ||
        u.contains('vm.tiktok.com') ||
        u.contains('fb.watch') ||
        (u.contains('facebook.com') && u.contains('/share/')) ||
        u.contains('on.soundcloud.com');
  }

  /// Does the server's error text indicate a blocked platform (cookies)?
  static bool isPlatformBlockedError(String error) {
    final e = error.toLowerCase();
    return MTConstants.platformBlockedMarkers.any(e.contains);
  }
}
