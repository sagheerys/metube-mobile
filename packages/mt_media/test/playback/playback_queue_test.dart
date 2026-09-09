import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mt_media/mt_media.dart';

PlaylistItem _item(String id) => PlaylistItem(
  canonicalUrl: 'https://x/$id',
  title: id,
  serverFilename: '$id.mp4',
);

final _five = [
  for (final id in ['a', 'b', 'c', 'd', 'e']) _item(id),
];

void main() {
  group('the ordinary order', () {
    test('it starts at the requested index', () {
      final queue = PlaybackQueue(items: _five, index: 2);
      expect(queue.current!.title, 'c');
      expect(queue.index, 2);
    });

    test('an index out of range is clamped', () {
      expect(PlaybackQueue(items: _five, index: 99).index, 4);
      expect(PlaybackQueue(items: _five, index: -3).index, 0);
    });

    test('an empty list: no current and no next', () {
      final queue = PlaybackQueue(items: const []);
      expect(queue.current, isNull);
      expect(queue.index, -1);
      expect(queue.nextIndex(PlayMode.autoNext), isNull);
    });
  });

  group('the play modes', () {
    test('automatic: the next, then it stops at the end', () {
      final queue = PlaybackQueue(items: _five, index: 3);
      expect(queue.nextIndex(PlayMode.autoNext), 4);
      queue.jumpTo(4);
      expect(queue.nextIndex(PlayMode.autoNext), isNull);
    });

    test('repeat all wraps from the end to the start, and back', () {
      final queue = PlaybackQueue(items: _five, index: 4);
      expect(queue.nextIndex(PlayMode.repeatAll), 0);
      queue.jumpTo(0);
      expect(queue.previousIndex(PlayMode.repeatAll), 4);
    });

    test('stop at the end does not wrap', () {
      final queue = PlaybackQueue(items: _five, index: 4);
      expect(queue.nextIndex(PlayMode.stopAtEnd), isNull);
    });

    test('repeat one: on its own it replays itself', () {
      final queue = PlaybackQueue(items: _five, index: 1);
      expect(queue.nextIndex(PlayMode.repeatOne), 1);
    });

    test('repeat one does not trap the user who presses next', () {
      final queue = PlaybackQueue(items: _five, index: 1);
      expect(queue.nextIndex(PlayMode.repeatOne, userInitiated: true), 2);
      queue.jumpTo(4);
      expect(queue.nextIndex(PlayMode.repeatOne, userInitiated: true), 0);
    });

    test('previous from the head of the list, with no repeat, is nothing', () {
      final queue = PlaybackQueue(items: _five);
      expect(queue.previousIndex(PlayMode.autoNext), isNull);
    });
  });

  group('shuffle', () {
    test('it starts at the current item and covers every item once', () {
      final queue = PlaybackQueue(
        items: _five,
        index: 3,
        shuffle: true,
        random: Random(7),
      );
      expect(queue.current!.title, 'd');
      expect(queue.ordered.first.title, 'd');
      expect(queue.ordered.map((i) => i.title).toSet().length, 5);
    });

    test('it passes over every item without repeating, to the end', () {
      final queue = PlaybackQueue(
        items: _five,
        shuffle: true,
        random: Random(3),
      );
      final visited = <String>[queue.current!.title];
      while (queue.moveNext(PlayMode.autoNext)) {
        visited.add(queue.current!.title);
      }
      expect(visited.toSet().length, 5);
    });

    test('turning shuffle off restores the original order and keeps the current item', () {
      final queue = PlaybackQueue(
        items: _five,
        index: 2,
        shuffle: true,
        random: Random(11),
      );
      queue.setShuffle(false);
      expect(queue.current!.title, 'c');
      expect(queue.ordered.map((i) => i.title), ['a', 'b', 'c', 'd', 'e']);
      expect(queue.nextIndex(PlayMode.autoNext), 3);
    });
  });

  group(
    'removal, whether skipping something broken or removing from the sheet',
    () {
      test(
        'removing something other than the current keeps the current item',
        () {
          final queue = PlaybackQueue(items: _five, index: 3);
          expect(queue.removeAt(0), isTrue);
          expect(queue.current!.title, 'd');
          expect(queue.length, 4);
        },
      );

      test('removing the current moves to whatever took its place', () {
        final queue = PlaybackQueue(items: _five, index: 2);
        queue.removeAt(2);
        expect(queue.current!.title, 'd');
      });

      test('removing the last item while it is current falls back to the last one left', () {
        final queue = PlaybackQueue(items: _five, index: 4);
        queue.removeAt(4);
        expect(queue.current!.title, 'd');
      });

      test('removing everything leaves the queue empty', () {
        final queue = PlaybackQueue(items: [_item('only')]);
        queue.removeAt(0);
        expect(queue.isEmpty, isTrue);
        expect(queue.current, isNull);
      });

      test('an index out of range is refused', () {
        final queue = PlaybackQueue(items: _five);
        expect(queue.removeAt(9), isFalse);
        expect(queue.length, 5);
      });
    },
  );

  test('jumpTo refuses what is not in the queue', () {
    final queue = PlaybackQueue(items: _five);
    expect(queue.jumpTo(2), isTrue);
    expect(queue.jumpTo(50), isFalse);
    expect(queue.index, 2);
  });
}
