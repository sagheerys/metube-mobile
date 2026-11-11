import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/features/clip/clip_action_row.dart';
import 'package:metube_desktop/features/clip/clip_page.dart';
import 'package:metube_desktop/router.dart';
import 'package:metube_desktop/shell/player_bar.dart';
import 'package:metube_desktop/shell/right_panel.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:metube_desktop/shell/ui_zoom.dart';
import 'package:metube_desktop/shell/video_surface.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:mt_media/library.dart';
import 'package:mt_media/mt_media.dart';

import 'support/shell_harness.dart';

const _video = 'https://youtu.be/aaaaaaaaaaa';
const _shortA = 'https://youtu.be/sssssssssA1';
const _shortB = 'https://youtu.be/sssssssssB2';

LibraryItem _item(
  String url,
  String title, {
  int day = 20,
  bool audio = false,
  Duration? duration,
  double? ratio,
}) => LibraryItem(
  canonicalUrl: url,
  title: title,
  uploader: 'Field Notes',
  onServer: true,
  isAudio: audio,
  timestamp: DateTime(2026, 10, day),
  sizeBytes: 100,
  duration: duration,
  aspectRatio: ratio,
);

// Newest first on screen: short A, the video, short B, the audio.
final _library = [
  _item(_shortA, 'Tidepools at Dawn', day: 23, duration: _s(40), ratio: 0.56),
  _item(_video, 'Homelab Hour - Ep. 12', day: 22, duration: _s(2500)),
  _item(_shortB, 'Blue Hour', day: 21, duration: _s(30), ratio: 0.56),
  _item('https://youtu.be/bbbbbbbbbbb', 'Amber Skies', audio: true),
];

Duration _s(int seconds) => Duration(seconds: seconds);

PlaylistItem _playing(String url) =>
    toPlaylistItem(_library.firstWhere((i) => i.canonicalUrl == url));

void main() {
  Future<ShellHarness> open(
    WidgetTester tester, {
    UiZoom zoom = const UiZoom(1.0),
  }) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    final h = ShellHarness(
      library: _library,
      server: ServerConfig(baseUrl: 'http://nas:8081'),
      zoom: zoom,
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    return h;
  }

  /// A clip's title on its library card, not in the bar or the panel.
  Finder cardOf(String title) => find
      .descendant(of: find.byType(MTMediaGridCard), matching: find.text(title))
      .first;

  Future<void> rightClick(WidgetTester tester, Offset at) async {
    await tester.tapAt(
      at,
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a double click on a video opens its page and plays the list from it',
    (tester) async {
      final h = await open(tester);
      await doubleClick(tester, cardOf('Homelab Hour - Ep. 12'));
      await tester.pumpAndSettle();
      expect(h.player.calls, ['loop false', 'playItems']);
      expect(find.byType(ClipPage), findsOneWidget);
      // Not playing yet in the fake, so its cover offers play.
      expect(find.byKey(InertVideoSurface.pictureKey), findsNothing);

      h.player.showPlaying([_playing(_video)]);
      await tester.pumpAndSettle();
      expect(find.byKey(InertVideoSurface.pictureKey), findsOneWidget);
    },
  );

  Future<ShellHarness> onVideo(WidgetTester tester, {UiZoom? zoom}) async {
    final h = await open(tester, zoom: zoom ?? const UiZoom(1.0));
    // Paused: a playing card's equalizer never lets the test settle.
    h.player.showPlaying([_playing(_video)], playing: false);
    await doubleClick(tester, cardOf('Homelab Hour - Ep. 12'));
    await tester.pumpAndSettle();
    return h;
  }

  // Owner's request 2026-11-11: copied to look it up elsewhere.
  testWidgets('**the guard**: the title on the clip page and in the details '
      'panel can be selected and copied', (tester) async {
    await onVideo(tester);
    Finder selectable(Finder within) => find.ancestor(
      of: find.descendant(
        of: within,
        matching: find.text('Homelab Hour - Ep. 12'),
      ),
      matching: find.byType(SelectionArea),
    );
    expect(selectable(find.byType(ClipPage)), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(EmberRightPanel),
        matching: find.text('Details'),
      ),
    );
    await tester.pumpAndSettle();
    expect(selectable(find.byType(EmberRightPanel)), findsOneWidget);
  });

  testWidgets('audio only puts the cover in place of the picture', (
    tester,
  ) async {
    final h = await onVideo(tester);
    await tester.tap(find.text('Audio only'));
    await tester.pumpAndSettle();
    expect(h.video.calls, ['audioOnly true']);
    expect(find.byKey(InertVideoSurface.pictureKey), findsNothing);
  });

  testWidgets('theater widens the picture over the side panel', (tester) async {
    await onVideo(tester);
    expect(find.byType(EmberRightPanel), findsOneWidget);
    await tester.tap(find.text('Theater'));
    await tester.pumpAndSettle();
    expect(find.byType(EmberRightPanel), findsNothing);

    // Only on a clip's page: the library has its panel back.
    await tester.tap(
      find.descendant(
        of: find.byType(EmberSidebar),
        matching: find.text('Library'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EmberRightPanel), findsOneWidget);
  });

  testWidgets('F11 fills the screen with the picture, Esc comes back', (
    tester,
  ) async {
    final h = await onVideo(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.f11);
    await tester.pumpAndSettle();
    expect(h.controls.calls, contains('fullScreen true'));
    expect(find.byType(EmberSidebar), findsNothing);
    // The picture's own controls take the bar's place (the owner's
    // choice, 2026-10-28).
    expect(find.byType(EmberPlayerBar), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(h.controls.calls.last, 'fullScreen false');
    expect(find.byType(EmberSidebar), findsOneWidget);
  });

  testWidgets('the favourite button marks the clip', (tester) async {
    final h = await onVideo(tester);
    // A round button named in its tooltip and to a screen reader.
    await tester.tap(
      find.descendant(
        of: find.byType(ClipActionRow),
        matching: find.bySemanticsLabel('Add to favorites'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      await TagsIndex(store: h.store, mutex: PrefsMutex()).tagsOf(_video),
      [MTConstants.favoritesSystemTag],
    );
  });

  testWidgets('**the guard**: at 125% the right-click menu opens at the '
      'pointer', (tester) async {
    await onVideo(tester, zoom: const UiZoom(1.25));
    final at = tester.getCenter(find.byKey(InertVideoSurface.pictureKey));
    await rightClick(tester, at);
    final menu = tester.getRect(find.text('Add to playlist').last);
    // The first row starts just below and beside the pointer, not a
    // quarter of the window away.
    expect((menu.left - at.dx).abs(), lessThan(80));
    expect((menu.top - at.dy).abs(), lessThan(60));
  });

  testWidgets('deleting from the server asks first, then forgets the clip', (
    tester,
  ) async {
    final h = await onVideo(tester);
    await TagsIndex(
      store: h.store,
      mutex: PrefsMutex(),
    ).toggleTag(_video, 'homelab');
    await rightClick(
      tester,
      tester.getCenter(find.byKey(InertVideoSurface.pictureKey)),
    );
    await tester.tap(find.text('Delete from server'));
    await tester.pumpAndSettle();

    // Asked; cancelling deletes nothing.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(h.api.deleted, isEmpty);

    await rightClick(
      tester,
      tester.getCenter(find.byKey(InertVideoSurface.pictureKey)),
    );
    await tester.tap(find.text('Delete from server'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(h.api.deleted, [
      [_video],
    ]);
    expect(h.player.calls, contains('stop'));
    expect(
      await TagsIndex(store: h.store, mutex: PrefsMutex()).tagsOf(_video),
      isEmpty,
    );
    expect(find.byType(ClipPage), findsNothing);
  });

  testWidgets('**the guard**: a server that refuses the delete leaves the '
      'clip playing and its page open, and says why', (tester) async {
    final h = await onVideo(tester);
    h.api.deleteError = const NetworkException('down');
    await rightClick(
      tester,
      tester.getCenter(find.byKey(InertVideoSurface.pictureKey)),
    );
    await tester.tap(find.text('Delete from server'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(h.api.deleted, isEmpty);
    expect(h.player.calls, isNot(contains('stop')));
    expect(find.byType(ClipPage), findsOneWidget);
    expect(find.byType(MTNotice), findsOneWidget);
  });

  testWidgets('**the guard**: a clip only on this computer is not offered '
      'deleting from the server on its page', (tester) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    final local = LibraryItem(
      canonicalUrl: _video,
      title: 'Homelab Hour - Ep. 12',
      localPath: r'C:\Videos\MeTube\Offline\homelab.mp4',
      timestamp: DateTime(2026, 10, 22),
      duration: _s(2500),
    );
    final h = ShellHarness(
      library: [local],
      server: ServerConfig(baseUrl: 'http://nas:8081'),
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    h.player.showPlaying([toPlaylistItem(local)], playing: false);
    await doubleClick(tester, cardOf('Homelab Hour - Ep. 12'));
    await tester.pumpAndSettle();
    await rightClick(
      tester,
      tester.getCenter(find.byKey(InertVideoSurface.pictureKey)),
    );
    expect(find.text('Copy link'), findsOneWidget);
    expect(find.text('Delete from server'), findsNothing);
  });

  testWidgets('**the guard**: a clip with a copy here keeps its tags', (
    tester,
  ) async {
    // Deleting from the server must not take the computer's copy out of
    // the library: it lives on as local-only, with all it carries.
    final dir = Directory.systemTemp.createTempSync('ember_keep_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final copy = File('${dir.path}/clip.mp4')..writeAsStringSync('x');
    final h = await onVideo(tester);
    await OfflineIndex(
      store: h.store,
      mutex: PrefsMutex(),
    ).put(_video, copy.path);
    await TagsIndex(
      store: h.store,
      mutex: PrefsMutex(),
    ).toggleTag(_video, 'homelab');
    await rightClick(
      tester,
      tester.getCenter(find.byKey(InertVideoSurface.pictureKey)),
    );
    await tester.tap(find.text('Delete from server'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(h.api.deleted, [
      [_video],
    ]);
    expect(
      await TagsIndex(store: h.store, mutex: PrefsMutex()).tagsOf(_video),
      ['homelab'],
    );
  });

  testWidgets('a short plays its lane in a 9:16 column, looping', (
    tester,
  ) async {
    final h = await open(tester);
    await doubleClick(tester, cardOf('Blue Hour'));
    await tester.pumpAndSettle();
    expect(h.player.calls, ['playItems', 'loop true']);
    h.player.showPlaying([_playing(_shortA), _playing(_shortB)]);
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) => w is AspectRatio && w.aspectRatio == 9 / 16,
      ),
      findsOneWidget,
    );

    h.player.calls.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    expect(h.player.calls, ['next', 'previous']);

    // The wheel moves too, one short a notch.
    h.player.calls.clear();
    final stage = tester.getCenter(find.byType(ClipPage));
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(stage));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 120)));
    expect(h.player.calls, ['next']);
  });

  testWidgets('a double click on a short marks it a favourite', (tester) async {
    final h = await open(tester);
    await doubleClick(tester, cardOf('Blue Hour'));
    await tester.pumpAndSettle();
    h.player.showPlaying([_playing(_shortB)]);
    await tester.pumpAndSettle();
    final stage = tester.getCenter(find.byKey(InertVideoSurface.pictureKey));
    await tester.tapAt(stage);
    await tester.pump(kDoubleTapMinTime);
    await tester.tapAt(stage);
    await tester.pumpAndSettle();
    expect(
      await TagsIndex(store: h.store, mutex: PrefsMutex()).tagsOf(_shortB),
      [MTConstants.favoritesSystemTag],
    );
  });

  testWidgets('**the guard**: leaving the shorts lets the loop go', (
    tester,
  ) async {
    final h = await open(tester);
    await doubleClick(tester, cardOf('Blue Hour'));
    await tester.pumpAndSettle();
    h.player.calls.clear();
    await tester.tap(
      find.descendant(
        of: find.byType(EmberSidebar),
        matching: find.text('Library'),
      ),
    );
    await tester.pumpAndSettle();
    expect(h.player.calls, ['loop false']);
  });

  testWidgets('the player bar title leads back to the clip', (tester) async {
    final h = await open(tester);
    h.player.showPlaying([_playing(_video)], playing: false);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(EmberPlayerBar),
        matching: find.text('Homelab Hour - Ep. 12'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ClipPage), findsOneWidget);
    expect(
      tester.widget<EmberSidebar>(find.byType(EmberSidebar)).current,
      EmberPlace.item,
    );
  });
}
