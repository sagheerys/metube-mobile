import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// The same scripted adapter the rest of the client tests use; kept local
/// so this file can be read on its own.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

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

(MeTubeApiClient, _FakeAdapter) _makeClient(
  ResponseBody Function(RequestOptions) handler,
) {
  final adapter = _FakeAdapter(handler);
  final dio = Dio()..httpClientAdapter = adapter;
  final client = MeTubeApiClient(
    config: ServerConfig(baseUrl: 'https://metube.example.com'),
    dio: dio,
  );
  return (client, adapter);
}

ResponseBody _json(String body, {int status = 200}) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

Map<String, dynamic> _body(RequestOptions options) =>
    json.decode(options.data as String) as Map<String, dynamic>;

const _oneRow = '''
[{"id":"a1","name":"Homelab Hour","url":"https://yt.example/@homelab",
  "enabled":true,"check_interval_minutes":120,"quality":"1080",
  "folder":"","title_regex":null,"skip_subscriber_only":false,
  "last_checked":1758300000.5,"seen_count":214,"error":null}]
''';

void main() {
  group('ChannelSubscription.fromJson (§2.7)', () {
    test('a full row is read field by field', () {
      final subs = ChannelSubscription.listFromJson(json.decode(_oneRow))!;
      final sub = subs.single;
      expect(sub.id, 'a1');
      expect(sub.name, 'Homelab Hour');
      expect(sub.url, 'https://yt.example/@homelab');
      expect(sub.enabled, isTrue);
      expect(sub.checkIntervalMinutes, 120);
      expect(sub.quality, '1080');
      expect(sub.titleRegex, isNull);
      expect(sub.seenCount, 214);
      expect(sub.error, isNull);
      expect(sub.hasError, isFalse);
    });

    test('last_checked is read as SECONDS, not milliseconds — a millisecond '
        'reading puts the date in the year 57000', () {
      final sub = ChannelSubscription.listFromJson(json.decode(_oneRow))!
          .single;
      expect(
        sub.lastChecked,
        DateTime.fromMillisecondsSinceEpoch(1758300001000 - 500),
      );
      expect(sub.lastChecked!.year, 2025);
    });

    test('zero and negative timestamps are "never checked", not 1970', () {
      for (final raw in [0, -1, 0.0]) {
        final sub = ChannelSubscription.fromJson({
          'id': 'x',
          'url': 'https://c',
          'last_checked': raw,
        })!;
        expect(sub.lastChecked, isNull, reason: 'for $raw');
      }
    });

    test('a missing "enabled" means enabled, so a working row is not '
        'shown as paused', () {
      final sub = ChannelSubscription.fromJson({
        'id': 'x',
        'url': 'https://c',
      })!;
      expect(sub.enabled, isTrue);
      expect(
        ChannelSubscription.fromJson({
          'id': 'x',
          'url': 'https://c',
          'enabled': false,
        })!.enabled,
        isFalse,
      );
    });

    test('a row with no id or no url is dropped, not guessed at', () {
      expect(ChannelSubscription.fromJson({'url': 'https://c'}), isNull);
      expect(ChannelSubscription.fromJson({'id': 'x'}), isNull);
      expect(ChannelSubscription.fromJson('nonsense'), isNull);
    });

    test('one malformed row does not take the list down with it', () {
      final subs = ChannelSubscription.listFromJson([
        {'id': 'a', 'url': 'https://a'},
        {'no': 'id'},
        {'id': 'b', 'url': 'https://b'},
      ])!;
      expect(subs.map((s) => s.id), ['a', 'b']);
    });

    test('a name the server lost falls back to the URL', () {
      final sub = ChannelSubscription.fromJson({
        'id': 'x',
        'url': 'https://c',
        'name': '   ',
      })!;
      expect(sub.name, 'https://c');
    });

    test('anything that is not an array is a refusal, not an empty list', () {
      expect(ChannelSubscription.listFromJson('<html>'), isNull);
      expect(ChannelSubscription.listFromJson({'done': []}), isNull);
      expect(ChannelSubscription.listFromJson(<dynamic>[]), isEmpty);
    });
  });

  group('fetchSubscriptions (§2.7)', () {
    test('reads the array from GET /subscriptions', () async {
      final (client, adapter) = _makeClient((o) => _json(_oneRow));
      final subs = await client.fetchSubscriptions();
      expect(subs!.single.name, 'Homelab Hour');
      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.path, contains('/subscriptions'));
    });

    test('an older MeTube answering 404 gives NULL, not an empty list: the '
        'screen must be hidden rather than shown empty', () async {
      final (client, _) = _makeClient((o) => _json('not found', status: 404));
      expect(await client.fetchSubscriptions(), isNull);
    });

    test('an HTML page from a proxy is null too', () async {
      final (client, _) = _makeClient((o) => _json('<html>hello</html>'));
      expect(await client.fetchSubscriptions(), isNull);
    });

    test('an empty array stays an empty list — the server can do '
        'subscriptions, there are simply none', () async {
      final (client, _) = _makeClient((o) => _json('[]'));
      expect(await client.fetchSubscriptions(), isEmpty);
    });
  });

  group('subscribe (§2.7)', () {
    test('sends the URL, the quality and the interval', () async {
      final (client, adapter) = _makeClient((o) => _json('{"status":"ok"}'));
      await client.subscribe(
        'https://www.youtube.com/@homelab',
        Quality.q1080,
        checkIntervalMinutes: 180,
      );
      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, contains('/subscribe'));
      final body = _body(req);
      expect(body['url'], 'https://www.youtube.com/@homelab');
      expect(body['quality'], '1080');
      expect(body['check_interval_minutes'], 180);
    });

    test('playlist_item_limit is NEVER sent: a limit would make a check that '
        'finds more new videos skip the rest permanently', () async {
      final (client, adapter) = _makeClient((o) => _json('{"status":"ok"}'));
      await client.subscribe(
        'https://www.youtube.com/@homelab',
        Quality.best,
        checkIntervalMinutes: 60,
      );
      expect(
        _body(adapter.requests.single),
        isNot(contains('playlist_item_limit')),
      );
    });

    test('the quality rule still applies: a numeric quality cannot escape '
        'to a non-YouTube channel', () async {
      final (client, adapter) = _makeClient((o) => _json('{"status":"ok"}'));
      await client.subscribe(
        'https://soundcloud.com/artist',
        Quality.q720,
        checkIntervalMinutes: 60,
      );
      expect(_body(adapter.requests.single)['quality'], Quality.best.wire);
    });

    test(
      'compatible video sends the three fields together, as /add does',
      () async {
        final (client, adapter) = _makeClient((o) => _json('{"status":"ok"}'));
        await client.subscribe(
          'https://www.youtube.com/@homelab',
          Quality.q720,
          checkIntervalMinutes: 60,
          compatibleVideo: true,
        );
        final body = _body(adapter.requests.single);
        expect(body['download_type'], 'video');
        expect(body['format'], 'mp4');
        expect(body['codec'], 'h264');
        // The preset rides with `best` only, exactly as in /add.
        expect(body.containsKey('ytdl_options_presets'), isFalse);
      },
    );

    test('a server that does not know the preset answers 400, and the call '
        'is retried without it', () async {
      var calls = 0;
      final (client, adapter) = _makeClient((o) {
        calls++;
        return calls == 1
            ? _json('{"status":"error","msg":"unknown preset"}', status: 400)
            : _json('{"status":"ok"}');
      });
      await client.subscribe(
        'https://www.youtube.com/@homelab',
        Quality.best,
        checkIntervalMinutes: 60,
        compatibleVideo: true,
      );
      expect(adapter.requests, hasLength(2));
      expect(_body(adapter.requests.first), contains('ytdl_options_presets'));
      expect(
        _body(adapter.requests.last).containsKey('ytdl_options_presets'),
        isFalse,
      );
    });

    test('a duplicate URL arrives as 200 with an error body and must still '
        'throw — the body is read, not the status', () async {
      final (client, _) = _makeClient(
        (o) =>
            _json('{"status":"error","msg":"This URL is already subscribed"}'),
      );
      expect(
        () => client.subscribe(
          'https://www.youtube.com/@homelab',
          Quality.best,
          checkIntervalMinutes: 60,
        ),
        throwsA(isA<ServerErrorException>()),
      );
    });

    test('an empty title filter is left out rather than sent blank', () async {
      final (client, adapter) = _makeClient((o) => _json('{"status":"ok"}'));
      await client.subscribe(
        'https://www.youtube.com/@homelab',
        Quality.best,
        checkIntervalMinutes: 60,
        titleRegex: '   ',
      );
      expect(_body(adapter.requests.single), isNot(contains('title_regex')));
    });
  });

  group('updateSubscription (§2.7)', () {
    test('only the changed fields are sent, beside the id', () async {
      final (client, adapter) = _makeClient((o) => _json('{"status":"ok"}'));
      await client.updateSubscription('a1', enabled: false);
      final body = _body(adapter.requests.single);
      expect(body, {'id': 'a1', 'enabled': false});
    });

    test(
      'clearing the filter sends an EMPTY STRING: the server only reads '
      'keys that are present, so null would silently keep the old filter',
      () async {
        final (client, adapter) = _makeClient((o) => _json('{"status":"ok"}'));
        await client.updateSubscription('a1', clearTitleRegex: true);
        expect(_body(adapter.requests.single)['title_regex'], '');
      },
    );

    test('a change set with nothing in it makes no request at all', () async {
      final (client, adapter) = _makeClient((o) => _json('{"status":"ok"}'));
      await client.updateSubscription('a1');
      expect(adapter.requests, isEmpty);
    });
  });

  group('deleteSubscriptions and checkSubscriptions (§2.7)', () {
    test('delete sends the ids', () async {
      final (client, adapter) = _makeClient((o) => _json('{"status":"ok"}'));
      await client.deleteSubscriptions(['a1', 'b2']);
      expect(_body(adapter.requests.single)['ids'], ['a1', 'b2']);
    });

    test('deleting nothing makes no request', () async {
      final (client, adapter) = _makeClient((o) => _json('{"status":"ok"}'));
      await client.deleteSubscriptions([]);
      expect(adapter.requests, isEmpty);
    });

    test(
      'check with no ids means every enabled one, and sends no ids key',
      () async {
        final (client, adapter) = _makeClient((o) => _json('{"status":"ok"}'));
        await client.checkSubscriptions();
        expect(_body(adapter.requests.single), isEmpty);
      },
    );

    test('check with ids sends exactly those', () async {
      final (client, adapter) = _makeClient((o) => _json('{"status":"ok"}'));
      await client.checkSubscriptions(ids: ['a1']);
      expect(_body(adapter.requests.single)['ids'], ['a1']);
    });

    test('an error body on check is reported, not swallowed', () async {
      final (client, _) = _makeClient(
        (o) => _json('{"status":"error","msg":"busy"}'),
      );
      expect(
        () => client.checkSubscriptions(),
        throwsA(isA<ServerErrorException>()),
      );
    });
  });
}
