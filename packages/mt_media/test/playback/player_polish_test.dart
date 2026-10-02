import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_media/src/playback/playback_state_mapping.dart';
import 'package:mt_ui/mt_ui.dart';

import 'fake_player_port.dart';

/// Three small touches from the design review of 2026-09-25: a next button
/// on the mini player, a close mark in place of the notification's stop
/// square, and a second notification line when a clip has no artist.
void main() {
  late MemoryKeyValueStore store;
  late MTAudioHandler handler;

  MTAudioHandler build() {
    final mutex = PrefsMutex();
    return MTAudioHandler(
      player: FakePlayerPort(),
      resolver: PlaybackSourceResolver(
        endpoint: ServerStreamEndpoint(
          buildUrl: (name) => 'https://srv/download/$name',
          headers: const {},
        ),
        fileExists: (_) => false,
      ),
      positions: PlaybackPositionStore(store: store, mutex: mutex),
      prefs: PlaybackPrefs(store: store, mutex: mutex),
      stateStore: AudioStateStore(store: store, mutex: mutex),
      saveInterval: const Duration(hours: 1),
    );
  }

  PlaylistItem clip(String id, {String? uploader, String host = 'x'}) =>
      PlaylistItem(
        canonicalUrl: 'https://$host/$id',
        title: id,
        uploader: uploader,
        serverFilename: '$id.mp3',
        isAudio: true,
      );

  setUp(() {
    store = MemoryKeyValueStore();
    handler = build();
  });
  tearDown(() => handler.dispose());

  group('the session stays alive between songs', () {
    // audio_service takes any move into idle as the end of the session and
    // stops the service, which also removes the notification and leaves
    // the foreground (see third_party/audio_service/PATCHES.md). just_audio reports idle for a moment
    // whenever it loads a new source, so a skip must never publish it.
    Future<List<AudioProcessingState>> statesDuring(
      Future<void> Function() act,
    ) async {
      final seen = <AudioProcessingState>[];
      final sub = handler.playbackState.listen(
        (s) => seen.add(s.processingState),
      );
      await act();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      return seen;
    }

    test('next, previous and a song ending never publish idle', () async {
      await handler.playItems([clip('a'), clip('b'), clip('c')]);
      final seen = await statesDuring(() async {
        await handler.skipToNext();
        await handler.skipToQueueItem(2);
        await handler.onCompleted();
      });
      expect(seen, isNot(contains(AudioProcessingState.idle)));
    });

    test('a real stop still publishes idle', () async {
      await handler.playItems([clip('a'), clip('b')]);
      final seen = await statesDuring(handler.stop);
      expect(seen.last, AudioProcessingState.idle);
    });
  });

  group('the notification close button', () {
    test('stop keeps its action and is drawn as a close mark', () {
      for (final playing in [true, false]) {
        final last = mtMediaControls(playing: playing).last;
        expect(last.action, MediaAction.stop);
        expect(last.androidIcon, 'drawable/$mtCloseIcon');
      }
    });

    test('both apps ship the drawable it names', () {
      // A missing resource resolves to id 0 and the button loses its icon.
      final root = Directory.current.parent.parent.path;
      for (final app in ['metube_lite', 'metube_super']) {
        final file = File(
          '$root/apps/$app/android/app/src/main/res/drawable/$mtCloseIcon.xml',
        );
        expect(file.existsSync(), isTrue, reason: app);
      }
    });
  });

  group('the notification second line', () {
    test('a clip with an artist shows only the artist, as before', () {
      final media = clip(
        'a',
        uploader: 'Fairuz',
        host: 'soundcloud.com',
      ).toMediaItem(playlistName: 'Morning');
      expect(media.artist, 'Fairuz');
      expect(media.album, isNull);
    });

    test('without an artist, the playlist it plays from', () {
      final media = clip(
        'a',
        host: 'soundcloud.com',
      ).toMediaItem(playlistName: 'Morning');
      expect(media.album, 'Morning');
    });

    test('without a playlist, the platform', () {
      expect(
        clip('a', host: 'soundcloud.com').toMediaItem().album,
        'SoundCloud',
      );
      expect(
        clip('a', host: 'www.instagram.com').toMediaItem().album,
        'Instagram',
      );
    });

    test('an unknown site leaves the line empty rather than say "Other"', () {
      expect(clip('a', host: 'example.org').toMediaItem().album, isNull);
    });

    test('the handler carries the playlist name, across a restart', () async {
      await handler.playItems(
        [clip('a'), clip('b')],
        playlistId: 'p1',
        playlistName: 'Morning',
      );
      expect(handler.mediaItem.value!.album, 'Morning');
      expect(handler.queue.value.last.album, 'Morning');

      await handler.persist();
      await handler.dispose();
      handler = build();
      expect(await handler.restoreSession(), isTrue);
      expect(handler.mediaItem.value!.album, 'Morning');
    });

    test(
      'a list played without a name does not inherit the last one',
      () async {
        await handler.playItems([clip('a')], playlistName: 'Morning');
        await handler.playItems([clip('b', host: 'soundcloud.com')]);
        expect(handler.mediaItem.value!.album, 'SoundCloud');
      },
    );
  });

  group('the mini player next button', () {
    Future<void> show(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: mtTheme(MTVariant.superApp, Brightness.light),
          locale: locale,
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          home: Scaffold(
            bottomNavigationBar: MTMiniPlayer(handler: handler, onOpen: () {}),
          ),
        ),
      );
      // The first frame starts the bar's entrance; the second ends it.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('it skips to the next item of a list', (tester) async {
      await tester.runAsync(() => handler.playItems([clip('a'), clip('b')]));
      await show(tester);
      // The skip loads a source, which is real asynchronous work.
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Next'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      expect(handler.currentItem!.title, 'b');
    });

    testWidgets('next sits to the right of play in Arabic too', (tester) async {
      await tester.runAsync(() => handler.playItems([clip('a'), clip('b')]));
      await show(tester, locale: const Locale('ar'));
      final l10n = tester.element(find.byType(MTMiniPlayer)).mtl;
      final play = tester.getCenter(find.byTooltip(l10n.play));
      final next = tester.getCenter(find.byTooltip(l10n.next));
      final close = tester.getCenter(find.byTooltip(l10n.closePlayer));
      expect(next.dx, greaterThan(play.dx));
      // The bar itself still reads right to left: close stays at its end.
      expect(close.dx, lessThan(play.dx));
    });

    testWidgets('a single clip has nothing to skip to, so no button', (
      tester,
    ) async {
      await tester.runAsync(() => handler.playItems([clip('a')]));
      await show(tester);
      expect(find.byTooltip('Next'), findsNothing);
      expect(find.byTooltip('Close player'), findsOneWidget);
    });
  });
}
