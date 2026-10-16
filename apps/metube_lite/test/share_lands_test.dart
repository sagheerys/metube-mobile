import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_lite/features/shell/share_landing.dart';

/// Field report 2026-10-16: a link shared while the app sat on the video
/// player opened the add sheet, and the sheet was gone 162 ms later. The
/// share goes back to the library tab first, which closes the player; a
/// sheet opened before that move is carried away with the player.
void main() {
  late StatefulNavigationShell shell;
  late BuildContext shellContext;

  GoRouter build() => GoRouter(
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          shell = navigationShell;
          return Builder(
            builder: (inner) {
              shellContext = inner;
              return Scaffold(body: navigationShell);
            },
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const Text('library')),
            ],
          ),
        ],
      ),
      GoRoute(path: '/player', builder: (_, _) => const Text('player')),
    ],
  );

  testWidgets('the sheet opened for a share outlives the player it closes', (
    tester,
  ) async {
    final router = build();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('/player');
    await tester.pumpAndSettle();
    expect(find.text('player'), findsOneWidget);

    // The share's own order: land, then open the sheet.
    final landed = landOnLibrary(shell).then((_) {
      if (!shellContext.mounted) return;
      showModalBottomSheet<void>(
        context: shellContext,
        useRootNavigator: true,
        builder: (_) => const Text('add sheet'),
      );
    });
    await tester.pump();
    await tester.pumpAndSettle();
    await landed;

    expect(find.text('player'), findsNothing);
    expect(find.text('add sheet'), findsOneWidget);
  });
}
