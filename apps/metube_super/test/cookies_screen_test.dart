import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/settings/cookies_screen.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

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

/// The system picker, answered with files chosen by the test.
class _FakePicker extends FilePicker {
  _FakePicker(this.files);

  final List<(String, String)> files;
  bool? askedForMany;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    askedForMany = allowMultiple;
    return FilePickerResult([
      for (final (name, text) in files)
        PlatformFile(
          name: name,
          size: text.length,
          bytes: Uint8List.fromList(utf8.encode(text)),
        ),
    ]);
  }
}

/// **The cookies screen**.
///
/// Its job is to be honest about three states the server can be in, and
/// to offer only the buttons that can succeed in each one.
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
      home: const CookiesScreen(),
    ),
  );

  Future<void> open(
    WidgetTester tester,
    ResponseBody Function(RequestOptions) handler,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 2200);
    addTearDown(tester.view.reset);
    final container = containerWith(handler);
    addTearDown(container.dispose);
    await tester.pumpWidget(host(container));
    await tester.pumpAndSettle();
  }

  testWidgets('a server holding cookies says so and offers to replace them', (
    tester,
  ) async {
    await open(tester, (_) => _json('{"status":"ok","has_cookies":true}'));

    expect(find.text('The server has cookies'), findsOneWidget);
    expect(find.text('Replace the cookies files'), findsOneWidget);
    expect(find.text('Delete the cookies'), findsOneWidget);
  });

  testWidgets(
    'a server with none offers no delete: a delete button that can only '
    'answer 400 teaches the user that the app is guessing',
    (tester) async {
      await open(tester, (_) => _json('{"status":"ok","has_cookies":false}'));

      expect(find.text('The server has no cookies'), findsOneWidget);
      expect(find.text('Choose cookies files'), findsOneWidget);
      expect(find.text('Delete the cookies'), findsNothing);
    },
  );

  testWidgets(
    'a MeTube too old to answer says "cannot say" rather than "no", and '
    'still lets the owner try the upload',
    (tester) async {
      await open(tester, (_) => _json('nope', status: 404));

      expect(
        find.text('This MeTube cannot say whether it has cookies'),
        findsOneWidget,
      );
      // Upload is still offered: the status endpoint being absent does not
      // mean the upload one is.
      expect(find.text('Choose cookies files'), findsOneWidget);
      expect(find.text('Delete the cookies'), findsNothing);
    },
  );

  /// What reached `/upload-cookies`, as text; null when nothing did.
  Future<String?> uploaded() async {
    final posts = adapter.requests.where(
      (r) => r.path.endsWith('/upload-cookies'),
    );
    if (posts.isEmpty) return null;
    final form = posts.single.data as FormData;
    final bytes = await form.files.single.value
        .clone()
        .finalize()
        .expand((chunk) => chunk)
        .toList();
    return utf8.decode(bytes);
  }

  String row(String domain, String name) =>
      [domain, 'TRUE', '/', 'TRUE', '1790000000', name, 'v'].join('\t');

  testWidgets('two platforms picked together reach the server as ONE file '
      'holding both — it keeps one file and replaces it whole, so two '
      'uploads would sign the first platform out (2026-09-24)', (tester) async {
    final picker = _FakePicker([
      (
        'youtube.txt',
        '# Netscape HTTP Cookie File\n${row('.youtube.com', 'SID')}\n',
      ),
      (
        'vimeo.txt',
        '# Netscape HTTP Cookie File\n${row('.vimeo.com', 'vuid')}\n',
      ),
    ]);
    FilePicker.platform = picker;
    await open(tester, (_) => _json('{"status":"ok","has_cookies":true}'));

    // The note that says so is on screen before anyone learns it the hard way.
    expect(find.textContaining('replaces the server'), findsOneWidget);
    await tester.tap(find.text('Replace the cookies files'));
    await tester.pumpAndSettle();

    expect(picker.askedForMany, isTrue);
    final sent = await uploaded();
    expect(sent, contains(row('.youtube.com', 'SID')));
    expect(sent, contains(row('.vimeo.com', 'vuid')));
    // And the screen says so by name: the only proof that both went in.
    expect(
      find.text('Cookies sent for: ${mtLtrRun('vimeo.com · youtube.com')}'),
      findsOneWidget,
    );
  });

  testWidgets('files with no cookie in them are refused on the phone, and '
      'the working file on the server is left alone', (tester) async {
    FilePicker.platform = _FakePicker([
      ('a.json', '[{"name":"SID"}]'),
      ('b.json', '[{"name":"vuid"}]'),
    ]);
    await open(tester, (_) => _json('{"status":"ok","has_cookies":true}'));

    await tester.tap(find.text('Replace the cookies files'));
    await tester.pumpAndSettle();

    expect(await uploaded(), isNull);
    expect(
      find.text('None of these files holds cookies in the Netscape format'),
      findsOneWidget,
    );
  });

  testWidgets('ONE file is sent exactly as picked, as it always was', (
    tester,
  ) async {
    const text = 'anything the server may judge for itself';
    FilePicker.platform = _FakePicker([('cookies.txt', text)]);
    await open(tester, (_) => _json('{"status":"ok","has_cookies":true}'));

    await tester.tap(find.text('Replace the cookies files'));
    await tester.pumpAndSettle();

    expect(await uploaded(), text);
  });

  testWidgets('the privacy line is always on screen, not behind a button', (
    tester,
  ) async {
    await open(tester, (_) => _json('{"status":"ok","has_cookies":false}'));
    expect(find.textContaining('never stored on this phone'), findsOneWidget);
    expect(find.textContaining('a server you own'), findsOneWidget);
  });

  testWidgets('deleting asks first, and sends nothing until it is confirmed', (
    tester,
  ) async {
    await open(tester, (o) {
      if (o.path.endsWith('/delete-cookies')) return _json('{"status":"ok"}');
      return _json('{"status":"ok","has_cookies":true}');
    });

    await tester.tap(find.text('Delete the cookies'));
    await tester.pumpAndSettle();

    expect(find.textContaining('will refuse again'), findsOneWidget);
    expect(
      adapter.requests.any((r) => r.path.contains('delete-cookies')),
      isFalse,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
      adapter.requests.any((r) => r.path.contains('delete-cookies')),
      isFalse,
    );
  });

  testWidgets('confirming sends the delete', (tester) async {
    await open(tester, (o) {
      if (o.path.endsWith('/delete-cookies')) return _json('{"status":"ok"}');
      return _json('{"status":"ok","has_cookies":true}');
    });

    await tester.tap(find.text('Delete the cookies'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(
      adapter.requests.any((r) => r.path.contains('delete-cookies')),
      isTrue,
    );
  });

  testWidgets('the layout holds on every device and text scale', (
    tester,
  ) async {
    final container = containerWith(
      (_) => _json('{"status":"ok","has_cookies":true}'),
    );
    addTearDown(container.dispose);
    await expectNoOverflow(tester, () => host(container));
  });

  testWidgets('and in Arabic', (tester) async {
    final container = containerWith(
      (_) => _json('{"status":"ok","has_cookies":true}'),
    );
    addTearDown(container.dispose);
    await expectNoOverflow(
      tester,
      () => host(container, locale: const Locale('ar')),
    );
  });
}
