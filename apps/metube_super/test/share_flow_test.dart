import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/home/background_hold.dart';
import 'package:metube_super/features/home/download_watcher.dart'
    show notificationsProvider;
import 'package:metube_super/features/home/notifications.dart';
import 'package:metube_super/features/library/device_pulls.dart';
import 'package:metube_super/features/library/library_actions.dart'
    show offlinePullProgressProvider;
import 'package:metube_super/features/library/share_flow.dart';
import 'package:metube_super/features/library/widgets/share_sheet.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

const _mb = 1024 * 1024;

/// Records what would have been posted, instead of posting it.
class _Notices extends DownloadNotifications {
  final List<(String title, String? payload)> posted = [];
  final List<int> cancelled = [];

  @override
  Future<void> showResult(
    int id, {
    required String title,
    required String body,
    required String channelName,
    String? payload,
    bool isError = false,
  }) async => posted.add((title, payload));

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  /// The progress notice, as (title, percent).
  final List<(String, int?)> progress = [];

  @override
  Future<void> showProgress(
    int id, {
    required String title,
    required String channelName,
    required int? percent,
    String? body,
  }) async => progress.add((title, percent));
}

/// A pull that waits for the test to let it finish.
class _Pull {
  final List<String> asked = [];
  Completer<void>? gate;
  TransferCancel? cancel;
  Object? fail;

  /// The pull may land on another name than the one asked for.
  String Function(String savePath) landsAt = (path) => path;

  Future<String> call({
    required String serverFilename,
    required String savePath,
    required void Function(int received, int total) onBytes,
    required TransferCancel cancel,
  }) async {
    asked.add(serverFilename);
    this.cancel = cancel;
    onBytes(50 * _mb, 100 * _mb);
    await gate?.future;
    if (cancel.isCancelled) throw const CancelledException();
    if (fail case final error?) throw error;
    final path = landsAt(savePath);
    await File(path).writeAsString('clip');
    return path;
  }
}

const _clip = LibraryItem(
  canonicalUrl: 'https://youtu.be/abc',
  title: 'A long talk',
  serverFilename: 'talk.mp4',
  onServer: true,
);

void main() {
  late Directory dir;
  late List<bool> held;
  late _Notices notices;
  late _Pull pull;
  late List<String> sent;
  late bool onScreen;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('share_flow');
    notices = _Notices();
    pull = _Pull();
    sent = [];
    onScreen = true;
    held = [];
  });

  tearDown(() => dir.delete(recursive: true));

  List<Override> overrides({Future<void> Function(String path)? send}) => [
    keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
    secretStoreProvider.overrideWithValue(MemorySecretStore()),
    prefsMutexProvider.overrideWithValue(PrefsMutex()),
    initialSettingsProvider.overrideWithValue(const SuperSettings()),
    loggerProvider.overrideWithValue(
      MTLogger(filePath: '${dir.path}/test.log'),
    ),
    notificationsProvider.overrideWithValue(notices),
    phonePullProvider.overrideWithValue(pull.call),
    freeBytesProvider.overrideWithValue((_) async => null),
    shareSendProvider.overrideWithValue(send ?? (path) async => sent.add(path)),
    shareDirProvider.overrideWith((ref) async => dir.path),
    shareForegroundProvider.overrideWithValue(() => onScreen),
    shareFrameProvider.overrideWithValue(() async {}),
    backgroundHoldProvider.overrideWithValue(
      BackgroundHold(
        start: () async {
          held.add(true);
          return true;
        },
        stop: () async => held.add(false),
      ),
    ),
  ];

  group('the flow', () {
    late ProviderContainer box;
    ShareFlow flow() => box.read(shareFlowProvider.notifier);

    // The pull starts after the folder is ready, a real-time moment later.
    Future<void> untilPulling() async {
      while (pull.asked.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    setUp(() => box = ProviderContainer(overrides: overrides()));
    tearDown(() => box.dispose());

    testWidgets('**the guard**: it shares the path the pull lands on, not '
        'the one it asked for', (tester) async {
      pull.landsAt = (path) => path.replaceFirst('.mp4', '(2).mp4');
      await tester.runAsync(() => flow().start(_clip));
      expect(sent, hasLength(1));
      expect(sent.single, endsWith('(2).mp4'));
      expect(File(sent.single).existsSync(), isTrue, reason: 'kept a while');
      expect(box.read(shareFlowProvider), isNull);
    });

    testWidgets('the sheet says the share menu is coming while Android '
        'copies the file', (tester) async {
      // Field report 2026-11-10: a large clip finished, then the app stood
      // still for seconds before the menu, with nothing on screen saying why.
      final phases = <SharePhase?>[];
      box.dispose();
      box = ProviderContainer(
        overrides: overrides(
          send: (path) async {
            phases.add(box.read(shareFlowProvider)?.phase);
            sent.add(path);
          },
        ),
      );
      await tester.runAsync(() => flow().start(_clip));
      expect(phases, [SharePhase.opening]);
      expect(box.read(shareFlowProvider), isNull, reason: 'gone after');
    });

    testWidgets('**the guard**: a second tap while one runs pulls once', (
      tester,
    ) async {
      await tester.runAsync(() async {
        // Made here, in the real zone: a completer made under fake time
        // would wait for a pump that never comes.
        pull.gate = Completer();
        final first = flow().start(_clip);
        await Future<void>.delayed(Duration.zero);
        final second = flow().start(_clip);
        pull.gate!.complete();
        await Future.wait([first, second]);
      });
      expect(pull.asked, hasLength(1));
      expect(sent, hasLength(1));
    });

    testWidgets('size, share and speed reach the sheet while it pulls', (
      tester,
    ) async {
      await tester.runAsync(() async {
        pull.gate = Completer();
        final running = flow().start(_clip);
        await untilPulling();
        final copy = box.read(
          devicePullsProvider,
        )[DevicePull.keyOf(PullKind.share, _clip.canonicalUrl)]!;
        expect(copy.received, 50 * _mb);
        expect(copy.total, 100 * _mb);
        expect(copy.progress, 0.5);
        pull.gate!.complete();
        await running;
      });
    });

    testWidgets('**the guard**: the background service is held while the '
        'copy runs, and let go once it is done', (tester) async {
      await tester.runAsync(() async {
        pull.gate = Completer();
        final running = flow().start(_clip);
        await untilPulling();
        expect(held, [true], reason: 'leaving the app would freeze the pull');
        pull.gate!.complete();
        await running;
        await Future<void>.delayed(Duration.zero);
      });
      expect(held, [true, false]);
    });

    testWidgets('**the guard**: cancel stops the pull and shares nothing', (
      tester,
    ) async {
      await tester.runAsync(() async {
        pull.gate = Completer();
        final running = flow().start(_clip);
        await untilPulling();
        flow().cancel();
        expect(pull.cancel!.isCancelled, isTrue);
        pull.gate!.complete();
        await running;
      });
      expect(sent, isEmpty);
      expect(box.read(shareFlowProvider), isNull);
    });

    testWidgets('**the guard**: done while the app is away, it says so and '
        'shares when the user comes back', (tester) async {
      onScreen = false;
      await tester.runAsync(() => flow().start(_clip));
      expect(sent, isEmpty, reason: 'the share menu cannot open from away');
      expect(notices.posted.single, ('Ready to share', _clip.canonicalUrl));
      expect(box.read(shareFlowProvider)?.phase, SharePhase.ready);

      onScreen = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(sent, hasLength(1));
      expect(notices.cancelled, contains(shareNotificationId));
      expect(notices.cancelled, contains(pullNoticeId));
      expect(box.read(shareFlowProvider), isNull);
    });

    testWidgets('**the guard**: a failure nobody sees becomes a notice, and '
        'the next tap starts again', (tester) async {
      pull.fail = const NetworkException('cut');
      await tester.runAsync(() => flow().start(_clip));
      expect(notices.posted.single.$1, 'Failed');
      expect(box.read(shareFlowProvider), isNull);
    });

    testWidgets('a failure the open sheet shows waits there to be read', (
      tester,
    ) async {
      pull.fail = const NetworkException('cut');
      flow().watched = true;
      await tester.runAsync(() => flow().start(_clip));
      expect(box.read(shareFlowProvider)?.phase, SharePhase.failed);
      expect(notices.posted, isEmpty);
      flow().dismiss();
      expect(box.read(shareFlowProvider), isNull);
    });
  });

  testWidgets('**the guard**: the card no longer reads 100% while the '
      'share menu is open', (tester) async {
    late ProviderContainer box;
    Map<String, double>? atMenu;
    box = ProviderContainer(
      overrides: overrides(
        send: (path) async => atMenu = box.read(offlinePullProgressProvider),
      ),
    );
    addTearDown(box.dispose);
    await tester.runAsync(
      () => box.read(shareFlowProvider.notifier).start(_clip),
    );
    expect(atMenu, isEmpty);
  });

  group('the folder', () {
    test('**the guard**: old copies and dead partial files go, a fresh '
        'copy stays for the app still reading it', () async {
      final old = DateTime.now().subtract(const Duration(hours: 2));
      final stale = File('${dir.path}/old.mp4')..writeAsStringSync('x');
      final dead = File('${dir.path}/cut.mp4.part')..writeAsStringSync('x');
      final fresh = File('${dir.path}/new.mp4')..writeAsStringSync('x');
      stale.setLastModifiedSync(old);
      dead.setLastModifiedSync(old);

      expect(await sweepShareFolder(dir.path), 2);
      expect(fresh.existsSync(), isTrue);
      expect(stale.existsSync() || dead.existsSync(), isFalse);
    });

    test('a folder that does not exist yet is not an error', () async {
      expect(await sweepShareFolder('${dir.path}/none'), 0);
    });
  });

  test('the speed is smoothed, not the last jump', () {
    final rate = TransferRate();
    expect(rate.sample(0, Duration.zero), isNull);
    expect(rate.sample(_mb, const Duration(milliseconds: 100)), isNull);
    expect(rate.sample(_mb, const Duration(seconds: 1)), _mb.toDouble());
    // A second at four times the speed moves it a third of the way.
    expect(rate.sample(5 * _mb, const Duration(seconds: 2)), 2 * _mb);
  });

  group('from the button', () {
    Widget app() => ProviderScope(
      overrides: overrides(),
      child: MaterialApp(
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => Column(
              children: [
                TextButton(
                  onPressed: () => shareClip(context, ref, _clip),
                  child: const Text('server'),
                ),
                TextButton(
                  onPressed: () => shareClip(
                    context,
                    ref,
                    const LibraryItem(
                      canonicalUrl: 'https://youtu.be/big',
                      title: 'Big',
                      serverFilename: 'big.mp4',
                      sizeBytes: 2 * shareConfirmBytes,
                    ),
                  ),
                  child: const Text('big'),
                ),
                TextButton(
                  onPressed: () => shareClip(
                    context,
                    ref,
                    LibraryItem(
                      canonicalUrl: 'https://youtu.be/here',
                      title: 'Here',
                      localPath: '${dir.path}/here.mp4',
                    ),
                  ),
                  child: const Text('local'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    testWidgets('a copy on the phone is shared at once, with no pull', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.tap(find.text('local'));
      await tester.pump();
      expect(sent, ['${dir.path}/here.mp4']);
      expect(pull.asked, isEmpty);
    });

    testWidgets('**the guard**: the sheet shows how far it has got, and '
        'closes itself when the share menu opens', (tester) async {
      await tester.pumpWidget(app());
      await tester.runAsync(() async {
        pull.gate = Completer();
        await tester.tap(find.text('server'));
        // Until the copy has begun, however busy the machine is.
        while (pull.asked.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Preparing to share'), findsOneWidget);
      expect(find.textContaining('50.0 MB'), findsOneWidget);
      expect(find.textContaining('50%'), findsOneWidget);

      await tester.runAsync(() async {
        pull.gate!.complete();
        // Until the share menu opens, however busy the machine is.
        while (sent.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      await tester.pumpAndSettle();
      expect(sent, hasLength(1));
      expect(find.byType(ShareSheet), findsNothing);
    });

    testWidgets('**the guard**: closed while the copy goes on, it says the '
        'copy goes on', (tester) async {
      await tester.pumpWidget(app());
      await tester.runAsync(() async {
        pull.gate = Completer();
        await tester.tap(find.text('server'));
        while (pull.asked.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ShareSheet), findsOneWidget);

      // A tap on the empty space above the sheet.
      await tester.tapAt(const Offset(20, 20));
      // The share began under real time, so its sheet closes there too.
      final notice = find.textContaining('Still preparing');
      for (var i = 0; i < 100 && notice.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ShareSheet), findsNothing);
      expect(notice, findsOneWidget);

      await tester.runAsync(() async {
        pull.gate!.complete();
        while (sent.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      await tester.pumpAndSettle();
    });

    testWidgets('a share that ends with the sheet open says nothing more', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.runAsync(() async {
        pull.gate = Completer();
        await tester.tap(find.text('server'));
        while (pull.asked.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(() async {
        pull.gate!.complete();
        while (sent.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('Still preparing'), findsNothing);
    });

    // Real time for the copy, frames for the screen, turn about: the share
    // begins under the test's frames and its file work under real time.
    Future<void> until(WidgetTester tester, bool Function() done) async {
      for (var i = 0; i < 400 && !done(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump();
      }
    }

    testWidgets('**the guard**: a large clip, once confirmed, shows its '
        'progress even when the card that asked is gone', (tester) async {
      final shown = ValueNotifier(true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: MaterialApp(
            theme: mtTheme(MTVariant.superApp, Brightness.light),
            localizationsDelegates: MTLocalizations.localizationsDelegates,
            supportedLocales: MTLocalizations.supportedLocales,
            home: Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: shown,
                builder: (_, on, _) => on
                    ? Consumer(
                        builder: (context, ref, _) => TextButton(
                          onPressed: () => shareClip(
                            context,
                            ref,
                            const LibraryItem(
                              canonicalUrl: 'https://youtu.be/big',
                              title: 'Big',
                              serverFilename: 'big.mp4',
                              sizeBytes: 2 * shareConfirmBytes,
                            ),
                          ),
                          child: const Text('big'),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('big'));
      await tester.pumpAndSettle();
      // The list rebuilds while the question is open, as a library does.
      shown.value = false;
      await tester.pump();
      await tester.runAsync(() async => pull.gate = Completer());
      await tester.tap(find.text('Download'));
      await until(tester, () => pull.asked.isNotEmpty);
      await tester.pump(const Duration(milliseconds: 400));
      expect(pull.asked, ['big.mp4'], reason: 'the share stopped in silence');
      expect(
        find.byType(ShareSheet),
        findsOneWidget,
        reason: 'nothing on screen reads as a tap that did not register',
      );
      await tester.runAsync(() async => pull.gate!.complete());
      await until(tester, () => sent.isNotEmpty);
      await tester.pumpAndSettle();
    });

    testWidgets('**the guard**: a large clip asks first, and no is no', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.tap(find.text('big'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Download'), findsWidgets);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(pull.asked, isEmpty);
      expect(find.byType(ShareSheet), findsNothing);
    });
  });

  group('every phone and text size', () {
    Widget sheet(ShareJob job) => ProviderScope(
      overrides: [
        ...overrides(),
        shareFlowProvider.overrideWith(() => _Fixed(job)),
        devicePullsProvider.overrideWith(
          () => _FixedPulls({
            DevicePull.keyOf(PullKind.share, job.url): DevicePull(
              kind: PullKind.share,
              url: job.url,
              title: job.title,
              received: 1500 * _mb,
              total: 3000 * _mb,
              rate: 12.5 * _mb,
            ),
          }),
        ),
      ],
      child: MaterialApp(
        theme: mtTheme(MTVariant.superApp, Brightness.dark),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        locale: const Locale('ar'),
        home: const Scaffold(
          body: Align(alignment: Alignment.bottomCenter, child: ShareSheet()),
        ),
      ),
    );

    testWidgets('pulling', (tester) async {
      await expectNoOverflow(
        tester,
        () => sheet(ShareJob(url: _clip.canonicalUrl, title: 'A' * 200)),
      );
    });

    testWidgets('failed', (tester) async {
      await expectNoOverflow(
        tester,
        () => sheet(
          ShareJob(
            url: _clip.canonicalUrl,
            title: _clip.title,
            phase: SharePhase.failed,
            error: const NetworkException('cut'),
          ),
        ),
      );
    });
  });
}

class _Fixed extends ShareFlow {
  _Fixed(this.job);

  final ShareJob job;

  @override
  ShareJob? build() => job;
}

class _FixedPulls extends DevicePulls {
  _FixedPulls(this.pulls);

  final Map<String, DevicePull> pulls;

  @override
  Map<String, DevicePull> build() => pulls;
}
