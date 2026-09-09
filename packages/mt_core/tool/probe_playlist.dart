// A temporary diagnostic probe; not meant for the repository.
import 'package:mt_core/mt_core.dart';

Future<void> main(List<String> args) async {
  for (final url in args) {
    print('--- $url');
    final kind = PlaylistDetector.detect(url);
    print('detect: $kind');
    final preview = switch (kind) {
      PlaylistKind.youtube => await YoutubePlaylistResolver().resolve(url),
      PlaylistKind.soundcloud => await SoundCloudResolver().resolveSet(url),
      PlaylistKind.none => null,
    };
    if (preview == null) {
      print('NULL');
      continue;
    }
    print('title: ${preview.title}  tracks=${preview.tracks.length}');
    print('cover: ${preview.coverUrl}');
    for (final t in preview.tracks.take(3)) {
      print('  • ${t.title} | ${t.duration} | ${t.url}');
    }
    if (preview.tracks.length > 3) {
      final last = preview.tracks.last;
      print('  … الأخير: ${last.title} | ${last.url}');
    }
  }
}
