import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/player/playback_providers.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

/// **Covers in the player (2026-10-10)**: the square cover asks YouTube
/// for its wide thumbnail, since the 4:3 one carries black bands; and no
/// cover request carries the server's password to anyone but the server.
void main() {
  const thumb = 'https://i.ytimg.com/vi/MfDROnE8FG8/hqdefault.jpg';
  final locked = MeTubeApiClient(
    config: ServerConfig(
      baseUrl: 'http://nas.local:8086',
      username: 'owner',
      password: 'secret',
    ),
  );

  Future<Widget?> build(
    WidgetTester tester,
    MTArtworkBuilder Function(WidgetRef ref) builder,
    String artwork,
  ) async {
    Widget? built;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          secretStoreProvider.overrideWithValue(MemorySecretStore()),
          initialSettingsProvider.overrideWithValue(const SuperSettings()),
          apiClientProvider.overrideWithValue(locked),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            built = builder(ref)(
              context,
              PlaylistItem(
                canonicalUrl: 'https://www.youtube.com/watch?v=MfDROnE8FG8',
                title: 'Across The Emerald Sea',
                artworkUrl: artwork,
                isAudio: true,
              ),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return built;
  }

  testWidgets('the square cover asks for the wide YouTube thumbnail', (
    tester,
  ) async {
    final cover = await build(tester, coverBuilderFor, thumb);
    expect(
      (cover! as CachedNetworkImage).imageUrl,
      'https://i.ytimg.com/vi/MfDROnE8FG8/maxresdefault.jpg',
    );
  });

  testWidgets('a list row keeps the thumbnail it had', (tester) async {
    final row = await build(tester, artworkBuilderFor, thumb);
    expect((row! as CachedNetworkImage).imageUrl, thumb);
  });

  testWidgets('a YouTube cover never carries the server password', (
    tester,
  ) async {
    for (final builder in [artworkBuilderFor, coverBuilderFor]) {
      final image =
          (await build(tester, builder, thumb))! as CachedNetworkImage;
      expect(image.httpHeaders ?? const {}, isNot(contains('Authorization')));
    }
  });

  testWidgets('an image on the server itself still does', (tester) async {
    final image =
        (await build(tester, artworkBuilderFor, 'http://nas.local:8086/a.jpg'))!
            as CachedNetworkImage;
    expect(image.httpHeaders, contains('Authorization'));
  });
}
