import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/home/download_watcher.dart'
    show notificationsProvider;
import 'package:metube_super/features/home/notifications.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:metube_super/features/subscriptions/arrival_watcher.dart';
import 'package:metube_super/features/subscriptions/subscriptions_providers.dart';
import 'package:mt_core/mt_core.dart';

/// Records what would have been posted, instead of posting it.
class _SpyNotifications extends DownloadNotifications {
  final List<(String title, String body)> posted = [];

  @override
  Future<void> showResult(
    int id, {
    required String title,
    required String body,
    required String channelName,
    String? payload,
    bool isError = false,
  }) async {
    posted.add((title, body));
  }
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, {int status = 200}) => ResponseBody.fromString(
  body is String ? body : jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

/// **The notice for what the server fetched on its own**.
///
/// Every other notification here describes a task this app created. These
/// have none: MeTube decides, downloads, and the clip turns up in
/// `/history`. The traps are all in deciding what counts as new.
void main() {
  late MemoryKeyValueStore store;
  late _SpyNotifications spy;

  setUp(() {
    store = MemoryKeyValueStore();
    spy = _SpyNotifications();
  });

  HistoryResponse historyAt(List<(String url, String title, int ms)> rows) =>
      HistoryResponse.fromJson({
        'done': [
          for (final (url, title, ms) in rows)
            {
              'url': url,
              'title': title,
              'status': 'finished',
              'timestamp': ms,
              'filename': '$title.mp4',
            },
        ],
        'queue': <dynamic>[],
      });

  /// One enabled subscription unless [subscribed] says otherwise: without
  /// one, the watcher deliberately stays silent.
  ProviderContainer containerWith({
    bool subscribed = true,
    bool notify = true,
    int failFirst = 0,
  }) {
    var failures = failFirst;
    final api = MeTubeApiClient(
      config: ServerConfig(baseUrl: 'https://srv.example.com'),
      dio: Dio()
        ..httpClientAdapter = _Adapter(
          (_) => failures-- > 0
              ? _json('boom', status: 500)
              : _json(
                  subscribed
                      ? [
                          {
                            'id': 's1',
                            'name': 'Homelab Hour',
                            'url': 'https://yt.example/@homelab',
                            'enabled': true,
                            'check_interval_minutes': 60,
                          },
                        ]
                      : <dynamic>[],
                ),
        ),
    );
    return ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(
          SuperSettings(
            activeUrl: 'https://srv.example.com',
            notifyArrivals: notify,
          ),
        ),
        apiClientProvider.overrideWithValue(api),
        notificationsProvider.overrideWithValue(spy),
      ],
    );
  }

  /// Builds a watcher **without loading the subscriptions list first**.
  /// That is how the app starts: only the subscriptions screen watches the
  /// list, so it is still loading when the first `/history` lands. An
  /// earlier version of these tests loaded it here, and so guarded a state
  /// the app is never in while the real one went silent.
  Future<ArrivalWatcher> watcherIn(ProviderContainer container) async =>
      container.read(arrivalWatcherInstanceProvider);

  Future<Set<String>?> seenKeys() async =>
      (await store.getStringList(arrivalSeenKey))?.toSet();

  test('the first run announces NOTHING and only records what is there — a '
      'fresh install would otherwise report the whole server library as '
      'having just arrived', () async {
    final container = containerWith();
    addTearDown(container.dispose);
    final watcher = await watcherIn(container);

    await watcher.onHistory(
      historyAt([('https://v/1', 'One', 1000), ('https://v/2', 'Two', 2000)]),
    );

    expect(spy.posted, isEmpty);
    expect(await seenKeys(), {'https://v/1', 'https://v/2'});
  });

  test('a later item is announced once, and becomes seen', () async {
    final container = containerWith();
    addTearDown(container.dispose);
    final watcher = await watcherIn(container);

    await watcher.onHistory(historyAt([('https://v/1', 'One', 1000)]));
    await watcher.onHistory(
      historyAt([('https://v/1', 'One', 1000), ('https://v/2', 'Two', 5000)]),
    );

    expect(spy.posted, hasLength(1));
    expect(spy.posted.single.$2, 'Two');
    expect(await seenKeys(), {'https://v/1', 'https://v/2'});
  });

  test('the same batch is never announced twice, even though the library '
      'is re-read every two seconds during a download', () async {
    final container = containerWith();
    addTearDown(container.dispose);
    final watcher = await watcherIn(container);
    final second = historyAt([
      ('https://v/1', 'One', 1000),
      ('https://v/2', 'Two', 5000),
    ]);

    await watcher.onHistory(historyAt([('https://v/1', 'One', 1000)]));
    await watcher.onHistory(second);
    await watcher.onHistory(second);
    await watcher.onHistory(second);

    expect(spy.posted, hasLength(1));
  });

  test(
    'three arrivals are ONE notice, not three: a channel checked hourly '
    'delivers in batches, and a line per clip is why people turn it off',
    () async {
      final container = containerWith();
      addTearDown(container.dispose);
      final watcher = await watcherIn(container);

      await watcher.onHistory(historyAt([('https://v/0', 'Old', 100)]));
      await watcher.onHistory(
        historyAt([
          ('https://v/0', 'Old', 100),
          ('https://v/1', 'One', 5000),
          ('https://v/2', 'Two', 6000),
          ('https://v/3', 'Three', 7000),
        ]),
      );

      expect(spy.posted, hasLength(1));
      expect(spy.posted.single.$1, contains('3'));
      for (final title in ['One', 'Two', 'Three']) {
        expect(spy.posted.single.$2, contains(title));
      }
    },
  );

  test('what THIS app downloaded is not announced again — the engine already '
      'said so, and a second notice for one file is worse than none', () async {
    final container = containerWith();
    addTearDown(container.dispose);
    final watcher = await watcherIn(container);

    await watcher.onHistory(historyAt([('https://v/0', 'Old', 100)]));
    watcher.noteOwnTask('https://v/1');
    await watcher.onHistory(
      historyAt([('https://v/0', 'Old', 100), ('https://v/1', 'Mine', 5000)]),
    );

    expect(spy.posted, isEmpty);
    // Still accounted for, so it is not re-examined for ever.
    expect(await seenKeys(), contains('https://v/1'));
  });

  test(
    'one of ours and one of the server\'s: only the server\'s is named',
    () async {
      final container = containerWith();
      addTearDown(container.dispose);
      final watcher = await watcherIn(container);

      await watcher.onHistory(historyAt([('https://v/0', 'Old', 100)]));
      watcher.noteOwnTask('https://v/1');
      await watcher.onHistory(
        historyAt([
          ('https://v/0', 'Old', 100),
          ('https://v/1', 'Mine', 5000),
          ('https://v/2', 'Theirs', 6000),
        ]),
      );

      expect(spy.posted, hasLength(1));
      expect(spy.posted.single.$2, 'Theirs');
      expect(spy.posted.single.$2, isNot(contains('Mine')));
    },
  );

  test(
    'with no subscription at all the watcher stays silent: a clip queued '
    'from MeTube\'s own web page is not this app\'s news to report',
    () async {
      final container = containerWith(subscribed: false);
      addTearDown(container.dispose);
      final watcher = await watcherIn(container);

      await watcher.onHistory(historyAt([('https://v/0', 'Old', 100)]));
      await watcher.onHistory(
        historyAt([('https://v/0', 'Old', 100), ('https://v/1', 'New', 5000)]),
      );

      expect(spy.posted, isEmpty);
    },
  );

  test('the setting turns it off, and what arrived is still seen', () async {
    final container = containerWith(notify: false);
    addTearDown(container.dispose);
    final watcher = await watcherIn(container);

    await watcher.onHistory(historyAt([('https://v/0', 'Old', 100)]));
    await watcher.onHistory(
      historyAt([('https://v/0', 'Old', 100), ('https://v/1', 'New', 5000)]),
    );

    expect(spy.posted, isEmpty);
    // Otherwise switching the setting back on would announce a backlog.
    expect(await seenKeys(), contains('https://v/1'));
  });

  // Replaced on purpose (2026-09-24): "an item older than the watermark is
  // not news" documented the defect. MeTube stamps an item when it is
  // queued, so "older" was never "already seen".
  test('a clip QUEUED before the last one but FINISHED after it is still '
      'news — the timestamp watermark this replaced skipped exactly this '
      'one', () async {
    final container = containerWith();
    addTearDown(container.dispose);
    final watcher = await watcherIn(container);

    await watcher.onHistory(historyAt([('https://v/1', 'One', 5000)]));
    // Queued at 100 by the subscription, finished only now.
    await watcher.onHistory(
      historyAt([('https://v/1', 'One', 5000), ('https://v/0', 'Slow', 100)]),
    );

    expect(spy.posted, hasLength(1));
    expect(spy.posted.single.$2, 'Slow');
  });

  test('the subscriptions list still LOADING when the arrival lands is not '
      '"no subscriptions" — the case that silenced the notice on the '
      "owner's phone (2026-09-23)", () async {
    final container = containerWith();
    addTearDown(container.dispose);
    final watcher = await watcherIn(container);

    await watcher.onHistory(historyAt([('https://v/0', 'Old', 100)]));
    // Nothing has read the list: it is loading when this pass starts.
    expect(container.read(subscriptionsProvider).isLoading, isTrue);
    await watcher.onHistory(
      historyAt([('https://v/0', 'Old', 100), ('https://v/1', 'New', 5000)]),
    );

    expect(spy.posted, hasLength(1));
    expect(spy.posted.single.$2, 'New');
  });

  test('a list that cannot be read leaves the arrival UNSEEN, and the next '
      'read announces it', () async {
    final container = containerWith(failFirst: 1);
    addTearDown(container.dispose);
    final watcher = await watcherIn(container);
    final later = historyAt([
      ('https://v/0', 'Old', 100),
      ('https://v/1', 'New', 5000),
    ]);

    await watcher.onHistory(historyAt([('https://v/0', 'Old', 100)]));
    await watcher.onHistory(later);
    expect(spy.posted, isEmpty);
    expect(await seenKeys(), isNot(contains('https://v/1')));

    await watcher.onHistory(later);
    expect(spy.posted, hasLength(1));
  });

  test('another server is another library, not a thousand arrivals: no key '
      'in common is recorded silently', () async {
    final container = containerWith();
    addTearDown(container.dispose);
    final watcher = await watcherIn(container);

    await watcher.onHistory(historyAt([('https://a/1', 'A', 100)]));
    await watcher.onHistory(
      historyAt([('https://b/1', 'B1', 200), ('https://b/2', 'B2', 300)]),
    );

    expect(spy.posted, isEmpty);
    expect(await seenKeys(), {'https://b/1', 'https://b/2'});
  });

  test('a clip deleted and fetched again is news again', () async {
    final container = containerWith();
    addTearDown(container.dispose);
    final watcher = await watcherIn(container);

    await watcher.onHistory(
      historyAt([('https://v/0', 'Old', 100), ('https://v/1', 'One', 200)]),
    );
    await watcher.onHistory(historyAt([('https://v/0', 'Old', 100)]));
    await watcher.onHistory(
      historyAt([('https://v/0', 'Old', 100), ('https://v/1', 'One', 900)]),
    );

    expect(spy.posted, hasLength(1));
  });

  test("a test build's timestamp is carried over once: what it had passed "
      'stays seen, what came after is news, and the old key goes', () async {
    await store.setInt(arrivalWatermarkKey, 1000);
    final container = containerWith();
    addTearDown(container.dispose);
    final watcher = await watcherIn(container);

    await watcher.onHistory(
      historyAt([('https://v/0', 'Old', 500), ('https://v/1', 'New', 5000)]),
    );

    expect(spy.posted, hasLength(1));
    expect(spy.posted.single.$2, 'New');
    expect(await store.getInt(arrivalWatermarkKey), isNull);
  });
}
