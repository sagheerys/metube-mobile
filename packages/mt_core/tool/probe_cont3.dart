import 'dart:convert';
import 'package:mt_core/mt_core.dart';
Future<Object?> browse(Map<String, Object> extra) async {
  final body = await ioHttpPostJson(
    Uri.parse('https://www.youtube.com/youtubei/v1/browse?prettyPrint=false'),
    {'context': {'client': {'clientName': 'WEB', 'clientVersion': '2.20260902.01.00', 'hl': 'en'}}, ...extra});
  return json.decode(body);
}
Future<void> main() async {
  final first = await browse({'browseId': 'VLPL15B1E77BB5708555'});
  final next = await browse({'continuation': InnertubeParser.continuationToken(first)!});
  Map? sample;
  InnertubeParser.walk(next, (m) { if (sample == null && m.containsKey('lockupViewModel')) sample = m['lockupViewModel'] as Map; });
  print('keys=${sample!.keys.toList()}');
  print('contentId=${sample!['contentId']} contentType=${sample!['contentType']}');
  final t = sample!['metadata']?['lockupMetadataViewModel']?['title'];
  print('title=$t');
}
