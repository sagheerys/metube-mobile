import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_media/src/video/mt_video_frame.dart';
import 'package:mt_media/src/video/mt_video_open.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_platform.dart';

/// **A song in the video player (2026-10-10)**: a playlist mixing videos
/// and songs plays them all there, and a song has no picture, so the frame
/// was an empty black square. Its cover stands in.
void main() {
  const item = PlaylistItem(
    canonicalUrl: 'https://www.youtube.com/watch?v=MfDROnE8FG8',
    title: 'Across The Emerald Sea',
    isAudio: true,
  );

  Future<VideoPlayerController> open(WidgetTester tester, Size size) async {
    VideoPlayerPlatform.instance = FakeVideoPlatform(size: size);
    final controller = VideoPlayerController.networkUrl(
      Uri.parse('https://srv/download/a.m4a'),
    );
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);
    return controller;
  }

  Future<void> pump(WidgetTester tester, VideoPlayerController controller) =>
      tester.pumpWidget(
        MaterialApp(
          theme: mtTheme(MTVariant.superApp, Brightness.dark),
          home: Center(
            child: SizedBox(
              width: 640,
              child: MTVideoFrame(
                controller: controller,
                item: item,
                artwork: (_, _) => const ColoredBox(
                  key: Key('cover'),
                  color: Color(0xFF123456),
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('a song shows its cover in a wide frame', (tester) async {
    await pump(tester, await open(tester, Size.zero));
    expect(find.byKey(const Key('cover')), findsOneWidget);
    expect(find.byType(MTVideoView), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('cover'))),
      const Size(640, 360),
    );
  });

  testWidgets('a video shows its picture', (tester) async {
    await pump(tester, await open(tester, const Size(1920, 1080)));
    expect(find.byType(MTVideoView), findsOneWidget);
    expect(find.byKey(const Key('cover')), findsNothing);
  });
}
