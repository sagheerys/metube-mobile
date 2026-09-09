import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

import 'fake_api.dart';

void main() {
  late Directory tempDir;
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mtf_transfer_');
  });
  tearDown(() => tempDir.delete(recursive: true));

  String pathOf(String name) => '${tempDir.path}${Platform.pathSeparator}$name';

  Transfer makeTransfer(FakeApi api) =>
      Transfer(api: api, backoff: const [Duration.zero, Duration.zero]);

  group('Transfer (§2.4)', () {
    test('نجاح مباشر مع تقدم 0..1', () async {
      final api = FakeApi();
      final progress = <double>[];
      await makeTransfer(api).pull(
        serverFilename: 'a.mp4',
        savePath: pathOf('a.mp4'),
        onProgress: progress.add,
      );
      expect(await File(pathOf('a.mp4')).readAsString(), 'MEDIA-DATA');
      expect(progress, [0.5, 1.0]);
    });

    // A regression (field report 2026-09-02): "the clip appears in the
    // library before it has finished downloading". Lite's library is built
    // by **scanning the folder**, and Dio writes incrementally, so the
    // final file existed from the first byte.
    test('الملف النهائي لا يظهر إلا بعد الاكتمال — الجزئي في .part', () async {
      final api = FakeApi();
      final finalPath = pathOf('a.mp4');
      final partPath = '$finalPath${Transfer.partSuffix}';
      var existedDuringPull = false;

      await makeTransfer(api).pull(
        serverFilename: 'a.mp4',
        savePath: finalPath,
        onProgress: (_) {
          // While in progress: the partial file exists and the final one
          // does not.
          if (File(finalPath).existsSync()) existedDuringPull = true;
        },
      );

      expect(
        existedDuringPull,
        isFalse,
        reason: 'المسار النهائي ظهر قبل الاكتمال ⇒ يراه مسح المكتبة',
      );
      expect(File(finalPath).existsSync(), isTrue);
      expect(
        File(partPath).existsSync(),
        isFalse,
        reason: 'الجزئي يُعاد تسميته لا يُترك',
      );
      expect(
        Transfer.partSuffix,
        isNot(contains('mp4')),
        reason: 'اللاحقة يجب ألا تكون امتداد وسائط',
      );
    });

    test('فشل كل المحاولات ⇒ لا ملف نهائي ولا جزئي متروك', () async {
      final api = FakeApi()..failDownloadsBeforeSuccess = 99;
      final finalPath = pathOf('a.mp4');
      await expectLater(
        makeTransfer(api).pull(serverFilename: 'a.mp4', savePath: finalPath),
        throwsA(isA<NetworkException>()),
      );
      expect(File(finalPath).existsSync(), isFalse);
      expect(File('$finalPath${Transfer.partSuffix}').existsSync(), isFalse);
    });

    test('فشلان ثم نجاح: 3 محاولات وحذف الجزئي قبل كل واحدة', () async {
      final api = FakeApi()..failDownloadsBeforeSuccess = 2;
      await makeTransfer(api)
          .pull(serverFilename: 'a.mp4', savePath: pathOf('a.mp4'));
      expect(api.downloadCalls, 3);
      expect(
        await File(pathOf('a.mp4')).readAsString(),
        'MEDIA-DATA',
        reason: 'المحتوى الكامل لا الجزئي',
      );
    });

    test('فشل كل المحاولات ⇒ NetworkException والجزئي محذوف', () async {
      final api = FakeApi()..failDownloadsBeforeSuccess = 99;
      await expectLater(
        makeTransfer(api)
            .pull(serverFilename: 'a.mp4', savePath: pathOf('a.mp4')),
        throwsA(isA<NetworkException>()),
      );
      expect(api.downloadCalls, MTConstants.pullRetries);
      expect(File(pathOf('a.mp4')).existsSync(), isFalse);
    });

    test('الإلغاء أثناء السحب يحذف الجزئي ولا يعيد المحاولة', () async {
      final api = FakeApi()..hangDownloadUntilCancel = true;
      final token = CancelToken();
      final pulling = makeTransfer(api).pull(
        serverFilename: 'a.mp4',
        savePath: pathOf('a.mp4'),
        cancelToken: token,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      token.cancel();
      await expectLater(pulling, throwsA(isA<CancelledException>()));
      expect(api.downloadCalls, 1);
      expect(File(pathOf('a.mp4')).existsSync(), isFalse);
    });
  });
}
