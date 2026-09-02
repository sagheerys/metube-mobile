import 'dart:convert';
import 'dart:io';
import 'package:mt_core/mt_core.dart';

/// التقاط عينات حقيقية (القاعدة 8) — يُشغَّل يدوياً عند تغيّر المنصات.
Future<void> main() async {
  final browse = await ioHttpPostJson(
    Uri.parse('https://www.youtube.com/youtubei/v1/browse?prettyPrint=false'),
    {
      'context': {'client': {'clientName': 'WEB', 'clientVersion': '2.20260902.01.00', 'hl': 'en'}},
      'browseId': 'VLPLbpi6ZahtOH6Blw3RGYpWkSByi_T7Rygb',
    },
  );
  // نقتطع: نحتفظ بأول عنصرين فقط كي يبقى الـ fixture صغيراً ومقروءاً.
  final data = json.decode(browse);
  final lockups = <Object>[];
  InnertubeParser.walk(data, (m) {
    if (m.containsKey('lockupViewModel') && lockups.length < 2) {
      lockups.add(m);
    }
  });
  String? token;
  InnertubeParser.walk(data, (m) {
    if (m.containsKey('continuationItemViewModel')) token = json.encode(m);
  });
  File('test/fixtures/real/youtube_browse.json').writeAsStringSync(
    const JsonEncoder.withIndent(' ').convert({
      'contents': lockups,
      'metadata': {'playlistMetadataRenderer': {'title': 'Top Trending Videos of the Week'}},
      if (token != null) 'continuation': json.decode(token!),
    }),
  );
  print('youtube fixture: ${lockups.length} lockups, token=${token != null}');

  final html = await ioHttpGetString(
      Uri.parse('https://soundcloud.com/relaxcafemusic/sets/coffee-jazz'));
  final hydration = RegExp(r'window\.__sc_hydration\s*=\s*(\[.+?\])\s*;', dotAll: true)
      .firstMatch(html)!;
  final list = json.decode(hydration.group(1)!) as List;
  final trimmed = <Object?>[];
  for (final e in list) {
    if (e is! Map) continue;
    if (e['hydratable'] == 'apiClient') trimmed.add(e);
    if (e['hydratable'] == 'playlist') {
      final d = Map<String, dynamic>.from(e['data'] as Map);
      final tracks = (d['tracks'] as List);
      d['tracks'] = [
        ...tracks.where((t) => (t as Map)['permalink_url'] != null).take(2),
        ...tracks.where((t) => (t as Map)['permalink_url'] == null).take(3),
      ];
      trimmed.add({'hydratable': 'playlist', 'data': d});
    }
  }
  File('test/fixtures/real/soundcloud_set.html').writeAsStringSync(
      'window.__sc_hydration = ${json.encode(trimmed)};');
  print('soundcloud fixture written');
}
