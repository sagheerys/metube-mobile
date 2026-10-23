import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

void main() {
  group('serverReason: the first sentence of what the server said', () {
    test('drops the yt-dlp prefix, the extractor tag and the id', () {
      expect(
        serverReason('ERROR: [youtube] aaa: Video unavailable'),
        'Video unavailable',
      );
      expect(serverReason('ERROR: HTTP Error 429'), 'HTTP Error 429');
    });

    test('keeps the first line of several, as measured on a real server', () {
      expect(
        serverReason(
          '[youtube] This video is unavailable\nNo video formats found!\n'
          'Requested format is not available',
        ),
        'This video is unavailable',
      );
    });

    test('leaves a plain reason alone', () {
      expect(serverReason('URL is missing a host'), 'URL is missing a host');
      expect(serverReason('  timeout  '), 'timeout');
    });

    test('never returns less than it was given', () {
      expect(serverReason('[youtube]'), '[youtube]');
      expect(serverReason(''), '');
    });
  });
}
