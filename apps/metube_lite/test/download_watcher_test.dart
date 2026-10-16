import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/di.dart';
import 'package:metube_lite/features/home/download_watcher.dart';
import 'package:metube_lite/features/home/notifications.dart';
import 'package:metube_lite/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';

/// Posts nothing; remembers what is showing.
class _Notices extends DownloadNotifications {
  final showing = <int>{};

  @override
  Future<void> showProgress(
    int id, {
    required String title,
    required String channelName,
    required int? percent,
    String? body,
  }) async => showing.add(id);

  @override
  Future<void> showResult(
    int id, {
    required String title,
    required String body,
    required String channelName,
    String? payload,
    bool isError = false,
  }) async => showing.add(id);

  @override
  Future<void> cancel(int id) async => showing.remove(id);
}

/// Changing the server address replaces the engine, and its tasks leave the
/// list with no ending of their own. An ongoing notice, which cannot
/// be swiped away, must still go.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a task gone from the list takes its notice with it', () async {
    // The foreground service, answered so the watcher's chain moves on.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_background'),
          (call) async => true,
        );
    final notices = _Notices();
    final tasks = StreamController<List<DownloadTask>>();
    addTearDown(tasks.close);
    final container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(const LiteSettings()),
        loggerProvider.overrideWithValue(
          MTLogger(filePath: '${Directory.systemTemp.path}/mtf_test.log'),
        ),
        notificationsProvider.overrideWithValue(notices),
        engineTasksProvider.overrideWith((ref) => tasks.stream),
      ],
    );
    addTearDown(container.dispose);
    container.read(downloadWatcherProvider);

    final adding = DownloadTask(
      inputUrl: 'https://youtu.be/abc',
      quality: Quality.best,
    ).copyWith(phase: TaskPhase.adding);
    tasks.add([adding]);
    await pumpEventQueue();
    expect(notices.showing, hasLength(1));

    // The new engine's list, without the moved task.
    tasks.add(const []);
    await pumpEventQueue();
    expect(notices.showing, isEmpty);
  });
}
