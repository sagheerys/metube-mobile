import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

void main() {
  group('ServerPath', () {
    test('a file at the top is its own name, as before folders', () {
      expect(ServerPath.of(filename: 'clip.mp4'), 'clip.mp4');
      expect(ServerPath.of(folder: '', filename: 'clip.mp4'), 'clip.mp4');
    });

    test('the folder comes first, and stray slashes in it are dropped', () {
      expect(
        ServerPath.of(folder: 'Kids/Cartoons/', filename: 'a.mp4'),
        'Kids/Cartoons/a.mp4',
      );
      expect(ServerPath.of(folder: '/Kids', filename: 'a.mp4'), 'Kids/a.mp4');
    });

    test('a filename that holds subfolders keeps them', () {
      expect(
        ServerPath.of(folder: 'Subs', filename: 'Channel/clip.mp4'),
        'Subs/Channel/clip.mp4',
      );
    });

    // Measured on a real server 2026-10-22: an absolute outtmpl in
    // YTDL_OPTIONS writes the file at the top, and MeTube reports it as
    // "../name" relative to the folder that was asked for.
    test('a file written above its folder is found where it really is', () {
      expect(
        ServerPath.of(
          folder: 'MTF اختبار',
          filename: '../Me at the zoo [jNQXAC9IVRw].webm',
        ),
        'Me at the zoo [jNQXAC9IVRw].webm',
      );
      expect(ServerPath.of(folder: 'A/B', filename: '../c.mp4'), 'A/c.mp4');
    });

    test('a path that climbs above the downloads is kept, and refused', () {
      for (final path in [
        ServerPath.of(filename: '../secret')!,
        ServerPath.of(folder: 'A', filename: '../../secret')!,
        ServerPath.of(folder: 'A', filename: '../../../etc/passwd')!,
      ]) {
        expect(ServerPath.isSafe(path), isFalse, reason: path);
      }
    });

    test('no filename gives no path: one is never invented', () {
      expect(ServerPath.of(folder: 'Kids'), isNull);
      expect(ServerPath.of(filename: ''), isNull);
    });

    test(
      'an audio download is marked, and the mark is not part of its name',
      () {
        final path = ServerPath.of(
          folder: 'Music',
          filename: 'a.m4a',
          audio: true,
        )!;
        expect(ServerPath.isAudio(path), isTrue);
        expect(ServerPath.relative(path), 'Music/a.m4a');
        expect(ServerPath.basename(path), 'a.m4a');
        expect(ServerPath.folderOf(path), 'Music');
        expect(ServerPath.urlPath(path), 'audio_download/Music/a.m4a');
      },
    );

    test('a plain stored name still means the top of download/', () {
      expect(ServerPath.isAudio('a.m4a'), isFalse);
      expect(ServerPath.urlPath('a b.mp4'), 'download/a%20b.mp4');
      expect(ServerPath.folderOf('a.mp4'), '');
    });

    test('the guard applies below the route', () {
      expect(ServerPath.isSafe('/audio_download/Music/a.m4a'), isTrue);
      expect(ServerPath.isSafe('/audio_download/../a.m4a'), isFalse);
      expect(ServerPath.isSafe('/other/a.m4a'), isFalse);
      expect(ServerPath.isSafe('Kids/../../etc'), isFalse);
    });
  });
}
