import 'package:go_router/go_router.dart';
import 'package:mt_ui/mt_ui.dart';

import 'features/audio/audio_screen.dart';
import 'features/batch/batch_screen.dart';
import 'features/settings/language_screen.dart';
import 'features/library/library_screen.dart';
import 'features/player/player_screen.dart';
import 'features/player/reels_screen.dart';
import 'features/playlists/playlist_details_screen.dart';
import 'features/playlists/playlists_screen.dart';
import 'features/settings/about_screen.dart';
import 'features/settings/backup_screen.dart';
import 'features/settings/logs_screen.dart';
import 'features/settings/network_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shell/shell_screen.dart';

/// The single route table (`03-APP-FLOW.md` §1). No direct
/// Navigator.push.
final router = GoRouter(
  // Tells the shell what has opened above it so it can hide the floating
  // add button, which used to be drawn over every bottom sheet and dialog,
  // covering their content (field report).
  observers: [MTRouteDepth.instance],
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          ShellScreen(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/', builder: (_, _) => const LibraryScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/playlists',
              builder: (_, _) => const PlaylistsScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, state) => PlaylistDetailsScreen(
                    playlistId: state.pathParameters['id']!,
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (_, _) => const SettingsScreen(),
              routes: [
                GoRoute(
                  path: 'network',
                  builder: (_, _) => const NetworkScreen(),
                ),
                GoRoute(
                  path: 'language',
                  builder: (_, _) => const LanguageScreen(),
                ),
                GoRoute(path: 'logs', builder: (_, _) => const LogsScreen()),
                GoRoute(
                  path: 'backup',
                  builder: (_, _) => const BackupScreen(),
                ),
                GoRoute(path: 'about', builder: (_, _) => const AboutScreen()),
              ],
            ),
          ],
        ),
      ],
    ),
    // The batch screen: the URL is passed through `extra` by automatic
    // routing.
    GoRoute(
      path: '/batch',
      builder: (_, state) =>
          BatchScreen(playlistUrl: (state.extra ?? '').toString()),
    ),
    GoRoute(path: '/player', builder: (_, _) => const PlayerScreen()),
    GoRoute(path: '/reels', builder: (_, _) => const ReelsScreen()),
    // **The audio screen rises out of the mini player like a sheet** and is
    // dragged down to return to it (requested 2026-09-04), rather than the
    // horizontal slide used for every other route, because the relationship
    // here is "expanding" rather than "going deeper".
    GoRoute(
      path: '/audio',
      pageBuilder: (_, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const AudioScreen(),
        // **Non-opaque**: what is beneath stays drawn, so dragging it down
        // shows the cover and the mini player behind it rather than a black
        // background (reported with a screenshot 2026-09-04).
        opaque: false,
        transitionDuration: MTMotion.sheetPage,
        reverseTransitionDuration: MTMotion.page,
        transitionsBuilder: mtSheetPageTransition,
      ),
    ),
  ],
);
