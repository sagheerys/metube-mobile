import 'dart:io';
import 'dart:typed_data';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// جسم APK مزيّف: توقيع ZIP ثم حشو — المنزّل يفحص التوقيع لا المحتوى.
Uint8List fakeApk(int size) {
  final bytes = Uint8List(size);
  bytes.setAll(0, ApkDownloader.zipMagic);
  return bytes;
}

void main() {
  late HttpServer server;
  late Directory tmp;
  late String savePath;

  /// ما يردّه السيرفر في الطلب التالي — يُضبط في كل اختبار.
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

  test('ينزّل ويعيد التسمية ويبلّغ التقدّم', () async {
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
    // **لا مخلَّفات**: `.part` باقٍ يوهم الإقلاع التالي بتحديث جاهز.
    expect(part().existsSync(), isFalse);
  });

  test('**الحارس**: صفحة HTML بحالة 200 تُرفض ولا تُسلَّم للمثبّت', () async {
    // صفحة تسجيل دخول أو خطأ من GitHub تصل بحالة 200 وتُحفظ باسم
    // `.apk`؛ بلا فحص التوقيع يفتح المستخدم «حزمة تالفة» ولا يفهم لماذا.
    handler = (r) async => r.response.write('<html>Not Found</html>');

    await expectLater(
      ApkDownloader().download(url: url(), savePath: savePath),
      throwsA(isA<UpdateDownloadException>()),
    );
    expect(File(savePath).existsSync(), isFalse);
    expect(part().existsSync(), isFalse);
  });

  test('حجم مبتور يُرفض', () async {
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

  test('حالة HTTP خطأ تُرفض', () async {
    handler = (r) async => r.response.statusCode = HttpStatus.notFound;

    await expectLater(
      ApkDownloader().download(url: url(), savePath: savePath),
      throwsA(isA<UpdateDownloadException>()),
    );
    expect(part().existsSync(), isFalse);
  });

  test('الإلغاء يوقف التنزيل وينظّف', () async {
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
