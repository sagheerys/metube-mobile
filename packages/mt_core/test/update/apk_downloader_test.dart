import 'dart:io';
import 'dart:typed_data';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// A fake APK body: the ZIP signature followed by padding. The downloader
/// checks the signature, not the content.
Uint8List fakeApk(int size) {
  final bytes = Uint8List(size);
  bytes.setAll(0, ApkDownloader.zipMagic);
  return bytes;
}

void main() {
  late HttpServer server;
  late Directory tmp;
  late String savePath;

  /// What the server returns for the next request; set in each test.
  late Future<void> Function(HttpRequest) handler;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('mt_update_');
    savePath = '${tmp.path}${Platform.pathSeparator}update.apk';
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      await handler(request);
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  String url() => 'http://127.0.0.1:${server.port}/update.apk';
  File part() => File('$savePath.part');

  test('it downloads, renames, and reports progress', () async {
    final body = fakeApk(40000);
    handler = (r) async {
      r.response.headers.contentLength = body.length;
      r.response.add(body);
    };

    final seen = <double>[];
    final path = await ApkDownloader().download(
      url: url(),
      savePath: savePath,
      expectedSize: body.length,
      onProgress: seen.add,
    );

    expect(path, savePath);
    expect(File(savePath).lengthSync(), body.length);
    expect(seen.last, 1.0);
    // **No leftovers**: a surviving `.part` makes the next launch believe
    // an update is ready.
    expect(part().existsSync(), isFalse);
  });

  test('**the guard**: an HTML page with status 200 is refused and never handed to the installer', () async {
    // A GitHub login or error page arrives with status 200 and is saved as
    // `.apk`; without the signature check the user opens a "corrupt
    // package" and cannot tell why.
    handler = (r) async => r.response.write('<html>Not Found</html>');

    await expectLater(
      ApkDownloader().download(url: url(), savePath: savePath),
      throwsA(isA<UpdateDownloadException>()),
    );
    expect(File(savePath).existsSync(), isFalse);
    expect(part().existsSync(), isFalse);
  });

  test('a truncated size is refused', () async {
    final body = fakeApk(1000);
    handler = (r) async => r.response.add(body);

    await expectLater(
      ApkDownloader().download(
        url: url(),
        savePath: savePath,
        expectedSize: 5000,
      ),
      throwsA(isA<UpdateDownloadException>()),
    );
    expect(File(savePath).existsSync(), isFalse);
  });

  test('an error HTTP status is refused', () async {
    handler = (r) async => r.response.statusCode = HttpStatus.notFound;

    await expectLater(
      ApkDownloader().download(url: url(), savePath: savePath),
      throwsA(isA<UpdateDownloadException>()),
    );
    expect(part().existsSync(), isFalse);
  });

  test('cancelling stops the download and cleans up', () async {
    final chunk = fakeApk(8000);
    handler = (r) async {
      r.response.headers.contentLength = chunk.length * 10;
      for (var i = 0; i < 10; i++) {
        r.response.add(chunk);
        await r.response.flush();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    };

    final token = DownloadCancelToken();
    await expectLater(
      ApkDownloader().download(
        url: url(),
        savePath: savePath,
        onProgress: (p) {
          if (p > 0.2) token.cancel();
        },
        cancel: token,
      ),
      throwsA(isA<UpdateCancelledException>()),
    );
    expect(File(savePath).existsSync(), isFalse);
    expect(part().existsSync(), isFalse);
  });
}
