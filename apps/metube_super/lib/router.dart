import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_ui/mt_ui.dart';

import 'features/audio/audio_screen.dart';
import 'features/library/library_screen.dart';
import 'features/player/player_screen.dart';
import 'features/player/reels_screen.dart';
import 'features/settings/network_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shell/shell_screen.dart';

/// جدول المسارات الواحد (`03-APP-FLOW.md` §1) — لا Navigator.push مباشر.
final router = GoRouter(
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
              builder: (_, _) => const _PhasePlaceholder(
                  icon: Icons.queue_music_rounded)),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/settings',
            builder: (_, _) => const SettingsScreen(),
            routes: [
              GoRoute(
                  path: 'network',
                  builder: (_, _) => const NetworkScreen()),
              GoRoute(
                  path: 'logs',
                  builder: (_, _) => const _PhasePlaceholder(
                      icon: Icons.article_rounded)),
            ],
          ),
        ]),
      ],
    ),
    // شاشة الدفعي (6.3) — غلاف مؤقت؛ المشغلات صارت حقيقية (المرحلة 5).
    GoRoute(
        path: '/batch',
        builder: (_, _) =>
            const _PhasePlaceholder(icon: Icons.playlist_add_rounded)),
    GoRoute(path: '/player', builder: (_, _) => const PlayerScreen()),
    GoRoute(path: '/reels', builder: (_, _) => const ReelsScreen()),
    GoRoute(path: '/audio', builder: (_, _) => const AudioScreen()),
  ],
);

/// غلاف مؤقت لمسار تُبنى شاشته في مرحلة لاحقة من الخطة.
class _PhasePlaceholder extends StatelessWidget {
  const _PhasePlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    return Scaffold(
      appBar: AppBar(),
      body: MTEmptyState(
        icon: icon,
        title: l10n.appTitle,
        message: l10n.comingSoonPhase,
      ),
    );
  }
}
