import 'dart:convert';
import 'package:mt_core/mt_core.dart';

Future<void> main() async {
  final body = await ioHttpPostJson(
    Uri.parse('https://www.youtube.com/youtubei/v1/browse?prettyPrint=false'),
    {
      'context': {'client': {'clientName': 'WEB', 'clientVersion': '2.20260902.01.00', 'hl': 'en'}},
      'browseId': 'VLPL15B1E77BB5708555',
    },
  );
  final data = json.decode(body);
  final p = InnertubeParser.parseBrowse(data);
  print('tracks=${p?.tracks.length}');
  print('token=${InnertubeParser.continuationToken(data)?.substring(0, 30)}');
  var keys = <String>{};
  InnertubeParser.walk(data, (m) {
    for (final k in m.keys) {
      if (k.toString().contains('ontinuation')) keys.add(k.toString());
    }
  });
  print('keys=$keys');
}
