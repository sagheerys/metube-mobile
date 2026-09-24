import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:metube_super/features/subscriptions/subscriptions_screen.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

/// A scripted server: the real client, a fake transport. Every request is
/// recorded so the test can assert on the wire, not on the widgets alone.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(String body, {int status = 200}) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

const _twoRows = '''
[
 {"id":"a1","name":"Homelab Hour","url":"https://yt.example/@homelab",
  "enabled":true,"check_interval_minutes":120,"quality":"1080",
  "title_regex":null,"last_checked":1758300000.0,"seen_count":214,
  "error":null},
 {"id":"b2","name":"Slow Coffee","url":"https://yt.example/@coffee",
  "enabled":false,"check_interval_minutes":1440,"quality":"audio",
  "title_regex":"brew","last_checked":null,"seen_count":0,
  "error":"channel is private"}
]
''';

void main() {
  late _Adapter adapter;

  ProviderContainer containerWith(
    ResponseBody Function(RequestOptions) handler,
  ) {
    adapter = _Adapter(handler);
    final api = MeTubeApiClient(
      config: ServerConfig(baseUrl: 'https://srv.example.com'),
      dio: Dio()..httpClientAdapter = adapter,
    );
    return ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(
          const SuperSettings(activeUrl: 'https://srv.example.com'),
        ),
        apiClientProvider.overrideWithValue(api),
      ],
    );
  }

  Widget host(
    ProviderContainer container, {
    Locale locale = const Locale('en'),
  }) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: mtTheme(MTVariant.superApp, Brightness.light),
      locale: locale,
      localizationsDelegates: MTLocalizations.localizationsDelegates,
      supportedLocales: MTLocalizations.supportedLocales,
      home: const SubscriptionsScreen(),
    ),
  );

  Future<ProviderContainer> open(
    WidgetTester tester,
    ResponseBody Function(RequestOptions) handler, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 2200);
    addTearDown(tester.view.reset);
    final container = containerWith(handler);
    addTearDown(container.dispose);
    await tester.pumpWidget(host(container, locale: locale));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('the followed channels are listed with their state', (
    tester,
  ) async {
    await open(tester, (_) => _json(_twoRows));

    expect(find.text('Homelab Hour'), findsOneWidget);
    expect(find.text('Slow Coffee'), findsOneWidget);
    // The interval as words, not as a number of minutes.
    expect(find.text('Every 2 hours'), findsOneWidget);
    expect(find.text('Every 24 hours'), findsOneWidget);
    // **The server's own error text, verbatim**: it is the only clue about
    // a channel that went private.
    expect(find.text('channel is private'), findsOneWidget);
  });

  testWidgets(
    'a paused subscription shows its switch off and says so, rather than '
    'disappearing from the list',
    (tester) async {
      await open(tester, (_) => _json(_twoRows));

      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      // Sorted for reading: the one with an error comes first, and it is
      // the paused one here.
      expect(switches.first.value, isFalse);
      expect(switches.last.value, isTrue);
      expect(find.text('Paused'), findsOneWidget);
    },
  );

  testWidgets(
    'never checked is said in words, and seen_count is called KNOWN, not '
    'downloaded — it starts at the size of the channel',
    (tester) async {
      await open(tester, (_) => _json(_twoRows));

      expect(find.textContaining('Not checked yet'), findsOneWidget);
      expect(find.textContaining('214 videos known'), findsOneWidget);
      expect(find.textContaining('downloaded'), findsNothing);
    },
  );

  testWidgets(
    'an older MeTube answering 404 explains itself instead of showing an '
    'empty list nobody could fill',
    (tester) async {
      await open(tester, (_) => _json('not found', status: 404));

      expect(
        find.text('This MeTube is older than subscriptions'),
        findsOneWidget,
      );
      // **No way in**: the button would post to an endpoint that is not
      // there.
      expect(find.byType(FloatingActionButton), findsNothing);
    },
  );

  testWidgets('a server that can do subscriptions but has none invites the '
      'first one', (tester) async {
    await open(tester, (_) => _json('[]'));

    expect(find.text('No channels followed yet'), findsOneWidget);
    expect(find.text('Follow a channel'), findsWidgets);
  });

  testWidgets('pausing posts enabled:false for that id alone', (tester) async {
    await open(tester, (o) {
      if (o.path.endsWith('/subscriptions/update')) {
        return _json('{"status":"ok"}');
      }
      return _json(_twoRows);
    });

    // The second switch is the enabled one (Homelab Hour).
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    // Every action re-reads the list; letting that finish keeps its
    // request's timeout timer from outliving the test.
    await tester.pumpAndSettle(const Duration(seconds: 1));

    final update = adapter.requests.firstWhere(
      (r) => r.path.endsWith('/subscriptions/update'),
    );
    expect(json.decode(update.data as String), {'id': 'a1', 'enabled': false});
  });

  testWidgets(
    'unfollowing asks first, and says what is lost — the server forgets '
    'what it had already seen',
    (tester) async {
      await open(tester, (_) => _json(_twoRows));

      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unfollow').last);
      await tester.pumpAndSettle();

      // **The channel's name is isolated inside the question** (2026-09-20):
      // it comes from the server and may run the other way to the
      // interface around it, and the `?` then has no defined side to land
      // on. It is the same string with two invisible characters around the
      // name, so the assertion carries them rather than dropping them.
      expect(find.text('Unfollow ${mtName('Slow Coffee')}?'), findsOneWidget);
      expect(find.textContaining('forgets which videos'), findsOneWidget);
      // **Nothing has been sent yet.**
      expect(adapter.requests.any((r) => r.path.contains('delete')), isFalse);
    },
  );

  testWidgets('cancelling the confirmation deletes nothing', (tester) async {
    await open(tester, (_) => _json(_twoRows));

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unfollow').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(adapter.requests.any((r) => r.path.contains('delete')), isFalse);
  });

  testWidgets('tapping a channel name opens the channel itself, and the '
      'menu offers the same as its first line (asked 2026-09-24)', (
    tester,
  ) async {
    // No plugin is registered under test, so url_launcher falls back to
    // its method channel; answering it records what would have opened.
    final opened = <String>[];
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'launch') {
        opened.add((call.arguments as Map)['url'] as String);
        return true;
      }
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await open(tester, (_) => _json(_twoRows));

    await tester.tap(find.text('Homelab Hour'));
    await tester.pumpAndSettle();
    expect(opened, ['https://yt.example/@homelab']);

    await tester.tap(find.byIcon(Icons.more_vert_rounded).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open channel'));
    await tester.pumpAndSettle();
    // The channel with an error sorts first, so the last menu is Homelab's.
    expect(opened, [
      'https://yt.example/@homelab',
      'https://yt.example/@homelab',
    ]);
    // Opening is not a server action: nothing was sent besides the list.
    expect(adapter.requests.map((r) => r.method).toSet(), {'GET'});
  });

  testWidgets('the layout holds on every device and every text scale', (
    tester,
  ) async {
    final container = containerWith((_) => _json(_twoRows));
    addTearDown(container.dispose);
    await expectNoOverflow(tester, () => host(container));
  });

  testWidgets('and in Arabic, right to left', (tester) async {
    final container = containerWith((_) => _json(_twoRows));
    addTearDown(container.dispose);
    await expectNoOverflow(
      tester,
      () => host(container, locale: const Locale('ar')),
    );
  });
}
