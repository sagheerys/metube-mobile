// Repairs the effect of a matching bug: re-adds an item deleted by mistake
// and deletes a test item.
// dart tool/restore_item.dart <baseUrl> add <videoUrl>
// dart tool/restore_item.dart <baseUrl> delete <videoId11>
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:mt_core/mt_core.dart';

Future<void> main(List<String> args) async {
  final [baseUrl, command, value, ...] = args;
  final client = MeTubeApiClient(config: ServerConfig(baseUrl: baseUrl));
  try {
    switch (command) {
      case 'add':
        await client.add(value, Quality.best);
        print('OK add: $value');
      case 'delete':
        final history = await client.fetchHistory();
        final targets = [
          for (final item in history.done)
            if (UrlKit.youtubeVideoId(item.canonicalUrl) == value)
              item.canonicalUrl,
        ];
        if (targets.isEmpty) {
          print('لا عناصر بالمعرف $value');
        } else {
          await client.delete(targets);
          print('OK delete ${targets.length}: $targets');
        }
      default:
        print('أمر غير معروف');
        exit(64);
    }
  } finally {
    client.close();
  }
  exit(0);
}
