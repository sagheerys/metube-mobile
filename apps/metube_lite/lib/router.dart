import 'package:go_router/go_router.dart';
import 'package:mt_ui/mt_ui.dart';

import 'features/audio/audio_screen.dart';
import 'features/batch/batch_screen.dart';
import 'features/downloads_library/library_screen.dart';
import 'features/player/player_screen.dart';
import 'features/player/reels_screen.dart';
import 'features/playlists/playlist_details_screen.dart';
import 'features/playlists/playlists_screen.dart';
import 'features/settings/about_screen.dart';
import 'features/settings/backup_screen.dart';
import 'features/settings/logs_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shell/shell_screen.dart';

/// جدول المسارات الواحد (`03-APP-FLOW.md` §1) — لا Navigator.push مباشر.
/// خريطة Lite = خريطة Super **بلا** `/settings/network` (م-28 لـ Super).
final router = GoRouter(
  // م-2: يُعلم الغلافَ بما فُتح فوقه ليخفي زر الإضافة العائم — كان
  // يُرسم فوق كل ورقة سفلية وحوار فيحجب محتواها (بلاغ المالك).
  observers: [MTRouteDepth.instance],
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          ShellScreen(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/', builder: (_, _) => const LibraryScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/playlists',
            builder: (_, _) => const PlaylistsScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => PlaylistDetailsScreen(
                    playlistId: state.pathParameters['id']!),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/settings',
            builder: (_, _) => const SettingsScreen(),
            routes: [
              GoRoute(path: 'logs', builder: (_, _) => const LogsScreen()),
              GoRoute(path: 'backup', builder: (_, _) => const BackupScreen()),
              GoRoute(path: 'about', builder: (_, _) => const AboutScreen()),
            ],
          ),
        ]),
      ],
    ),
    // الدفعي (م-11): الرابط يُمرَّر عبر `extra` من التوجيه التلقائي (م-5).
    GoRoute(
      path: '/batch',
      builder: (_, state) =>
          BatchScreen(playlistUrl: (state.extra ?? '').toString()),
    ),
    GoRoute(path: '/player', builder: (_, _) => const PlayerScreen()),
    GoRoute(path: '/reels', builder: (_, _) => const ReelsScreen()),
    GoRoute(path: '/audio', builder: (_, _) => const AudioScreen()),
  ],
);
