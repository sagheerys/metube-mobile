import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/features/downloads_library/library_providers.dart';
import 'package:metube_lite/features/downloads_library/local_item.dart';
import 'package:metube_lite/features/downloads_library/media_access.dart';
import 'package:metube_lite/features/downloads_library/widgets/media_access_view.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:permission_handler/permission_handler.dart';

import 'device_matrix.dart';

/// **Field report 2026-09-16 (Galaxy S22 Ultra, fresh profile):** on the
/// first launch the app asked for notifications and nothing else, and the
/// library showed
/// `PathAccessException: Exists failed, path = '/storage/emulated/0/Download/MeTube_Lite'
/// (OS Error: Permission denied, errno = 13)`.
///
/// The media permissions were declared in the manifest and **never
/// requested**: the package that asks had been deleted as unused. These
/// tests hold the asker, its order, and the screen that offers it.
void main() {
  group('the gate', () {
    test('a permission already granted asks the user nothing', () async {
      final asked = <List<Permission>>[];
      final gate = MediaAccessGate(
        probe: () async => true,
        isGranted: (_) async => true,
        ask: (permissions) async {
          asked.add(permissions);
          return false;
        },
      );

      expect(await gate.ensure(), MediaAccess.granted);
      expect(asked, isEmpty);
    });

    /// **The measurement that changed this code** (owner's phone,
    /// 2026-09-16): with the permission revoked the folder still opened, so
    /// a gate that trusted the folder never asked, and the library showed
    /// "no downloads yet" over 28 files.
    test(
      'a folder that opens is not proof: the permission is still asked',
      () async {
        final asked = <List<Permission>>[];
        final gate = MediaAccessGate(
          probe: () async => true,
          isGranted: (_) async => false,
          ask: (permissions) async {
            asked.add(permissions);
            return false;
          },
        );

        expect(await gate.ensure(), MediaAccess.denied);
        expect(asked, isNotEmpty);
      },
    );

    test(
      'the old storage permission alone is access on an older phone',
      () async {
        final gate = MediaAccessGate(
          probe: () async => true,
          isGranted: (permission) async => permission == Permission.storage,
        );

        expect(await gate.hasAccess(), isTrue);
      },
    );

    test(
      'the Android 13 media permissions are asked before the old one',
      () async {
        final asked = <List<Permission>>[];
        final gate = MediaAccessGate(
          probe: () async => false,
          isGranted: (_) async => false,
          ask: (permissions) async {
            asked.add(permissions);
            return false;
          },
        );

        expect(await gate.ensure(), MediaAccess.denied);
        expect(asked, [
          const [Permission.videos, Permission.audio],
          const [Permission.storage],
        ]);
      },
    );

    test(
      'granted on the first ask: the older permission is never asked',
      () async {
        var granted = false;
        final asked = <List<Permission>>[];
        final gate = MediaAccessGate(
          probe: () async => true,
          isGranted: (_) async => granted,
          ask: (permissions) async {
            asked.add(permissions);
            granted = true;
            return false;
          },
        );

        expect(await gate.ensure(), MediaAccess.granted);
        expect(asked, hasLength(1));
      },
    );

    test(
      '"never ask again" is blocked, which is not the same as denied',
      () async {
        final gate = MediaAccessGate(
          probe: () async => false,
          isGranted: (_) async => false,
          ask: (_) async => true,
        );

        expect(await gate.ensure(), MediaAccess.blocked);
      },
    );

    test('a permission channel that throws is denied, not a crash', () async {
      final gate = MediaAccessGate(
        probe: () async => false,
        isGranted: (_) async => false,
        ask: (_) async => throw Exception('no plugin on this platform'),
      );

      expect(await gate.ensure(), MediaAccess.denied);
    });

    test(
      'the probe creates the folder rather than calling it missing',
      () async {
        final base = Directory.systemTemp.createTempSync('mtf_probe');
        addTearDown(() => base.deleteSync(recursive: true));
        final target = '${base.path}${Platform.pathSeparator}MeTube_Lite';

        expect(Directory(target).existsSync(), isFalse);
        expect(await probeMediaFolder(target), isTrue);
        expect(Directory(target).existsSync(), isTrue);
      },
    );
  });

  group('an empty library', () {
    test('with no permission it is hidden, not empty', () {
      expect(
        () => assertLibraryVisible(isEmpty: true, hasAccess: false),
        throwsA(isA<MediaAccessDeniedException>()),
      );
    });

    test('with the permission it is simply empty', () {
      expect(
        () => assertLibraryVisible(isEmpty: true, hasAccess: true),
        returnsNormally,
      );
    });

    test('files listed are shown whatever the permission API says', () {
      expect(
        () => assertLibraryVisible(isEmpty: false, hasAccess: false),
        returnsNormally,
      );
    });
  });

  group('the screen', () {
    Widget host({
      required MediaAccessGate gate,
      Locale locale = const Locale('ar'),
    }) => ProviderScope(
      overrides: [
        mediaAccessGateProvider.overrideWithValue(gate),
        localMediaProvider.overrideWith((ref) async => const <LocalItem>[]),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        theme: mtTheme(MTVariant.lite, Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: MediaAccessView()),
        ),
      ),
    );

    testWidgets('it offers the permission instead of printing an errno', (
      tester,
    ) async {
      var asked = 0;
      await tester.pumpWidget(
        host(
          gate: MediaAccessGate(
            probe: () async => true,
            isGranted: (_) async => (asked++) > 0,
            ask: (_) async => false,
          ),
        ),
      );
      await tester.pump();

      final l10n = await MTLocalizations.delegate.load(const Locale('ar'));
      expect(find.text(l10n.mediaAccessTitle), findsOneWidget);
      expect(find.text(l10n.mediaAccessMessage), findsOneWidget);

      await tester.tap(find.text(l10n.mediaAccessGrant));
      await tester.pumpAndSettle();
      expect(asked, greaterThan(0), reason: 'the button must ask Android');
    });

    testWidgets('when Android stops asking, it points at the settings', (
      tester,
    ) async {
      var settingsOpened = 0;
      await tester.pumpWidget(
        host(
          gate: MediaAccessGate(
            probe: () async => false,
            isGranted: (_) async => false,
            ask: (_) async => true,
            openSettings: () async {
              settingsOpened++;
              return true;
            },
          ),
        ),
      );
      await tester.pump();
      final l10n = await MTLocalizations.delegate.load(const Locale('ar'));

      await tester.tap(find.text(l10n.mediaAccessGrant));
      await tester.pumpAndSettle();
      expect(find.text(l10n.mediaAccessBlockedMessage), findsOneWidget);

      await tester.tap(find.text(l10n.mediaAccessOpenSettings));
      await tester.pumpAndSettle();
      expect(settingsOpened, 1);
    });

    testWidgets('device matrix: no overflow in Arabic or English', (
      tester,
    ) async {
      for (final locale in const [Locale('ar'), Locale('en')]) {
        await expectNoOverflow(
          tester,
          () => host(
            gate: MediaAccessGate(
              probe: () async => false,
              isGranted: (_) async => false,
              ask: (_) async => false,
            ),
            locale: locale,
          ),
        );
      }
    });
  });
}
