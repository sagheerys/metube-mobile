import 'dart:convert';
import 'package:mt_core/mt_core.dart';

Future<Object?> browse(Map<String, Object> extra) async {
  final body = await ioHttpPostJson(
    Uri.parse('https://www.youtube.com/youtubei/v1/browse?prettyPrint=false'),
    {
      'context': {'client': {'clientName': 'WEB', 'clientVersion': '2.20260902.01.00', 'hl': 'en'}},
      ...extra,
    },
  );
  return json.decode(body);
}

Future<void> main() async {
  final first = await browse({'browseId': 'VLPL15B1E77BB5708555'});
  final token = InnertubeParser.continuationToken(first);
  print('page1=${InnertubeParser.parseBrowse(first)?.tracks.length} token=${token != null}');
  try {
    final next = await browse({'continuation': token!});
    var lockups = 0;
    InnertubeParser.walk(next, (m) { if (m.containsKey('lockupViewModel')) lockups++; });
    print('page2 raw lockups=$lockups parsed=${InnertubeParser.parseBrowse(next)?.tracks.length}');
  } catch (e) {
    print('ERR: $e');
  }
}
