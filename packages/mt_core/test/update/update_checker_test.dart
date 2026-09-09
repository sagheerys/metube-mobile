import 'dart:convert';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// GitHub's `releases/latest` response, with the fields the parser actually
/// reads.
String release({
  String tag = 'v2.1.0',
  bool draft = false,
  bool prerelease = false,
  List<Map<String, Object?>>? assets,
}) => json.encode({
  'tag_name': tag,
  'name': 'MeTube Mobile $tag',
  'body': 'إصلاحات وتحسينات',
  'draft': draft,
  'prerelease': prerelease,
  'html_url': 'https://github.com/sagheerys/metube-mobile/releases/$tag',
  'published_at': '2026-09-20T10:00:00Z',
  'assets':
      assets ??
      [
        {
          'name': 'MeTube-Lite-$tag.apk',
          'browser_download_url': 'https://x/lite.apk',
          'size': 21000000,
        },
        {
          'name': 'MeTube-Super-$tag.apk',
          'browser_download_url': 'https://x/super.apk',
          'size': 24000000,
        },
      ],
});

UpdateChecker checkerOf(String body, {String marker = 'super'}) =>
    UpdateChecker(fetch: (_) async => body, assetMarker: marker);

void main() {
  group('choosing the asset', () {
    test(
      "**the guard**: each app takes its own file, not its sibling's",
      () async {
        // One release carries both apps' APKs; without matching the marker a
        // Lite user installs Super, the first asset in the list.
        final superRelease = await checkerOf(release())
            .check(currentVersion: '2.0.0');
        expect(superRelease!.apkUrl, 'https://x/super.apk');
        expect(superRelease.apkSize, 24000000);

        final liteRelease = await checkerOf(
          release(),
          marker: 'lite',
        ).check(currentVersion: '2.0.0');
        expect(liteRelease!.apkUrl, 'https://x/lite.apk');
      },
    );

    test('a release with no APK for this app means no update', () async {
      final body = release(
        assets: [
          {
            'name': 'MeTube-Lite-v2.1.0.apk',
            'browser_download_url': 'https://x/lite.apk',
            'size': 1,
          },
        ],
      );
      expect(await checkerOf(body).check(currentVersion: '2.0.0'), isNull);
    });

    test('it ignores the non-installable attachments', () async {
      final body = release(
        assets: [
          {
            'name': 'metube-super-sources.zip',
            'browser_download_url': 'https://x/src.zip',
            'size': 5,
          },
          {
            'name': 'MeTube-Super-v2.1.0.apk',
            'browser_download_url': 'https://x/super.apk',
            'size': 7,
          },
        ],
      );
      final r = await checkerOf(body).check(currentVersion: '2.0.0');
      expect(r!.apkUrl, 'https://x/super.apk');
    });
  });

  group('the display policy', () {
    test('it does not offer what is not newer', () async {
      final c = checkerOf(release(tag: 'v2.0.0'));
      expect(await c.check(currentVersion: '2.0.0'), isNull);
      expect(await c.check(currentVersion: '2.1.0'), isNull);
    });

    test('a draft and a pre-release are both refused', () async {
      expect(
        await checkerOf(release(draft: true)).check(currentVersion: '2.0.0'),
        isNull,
      );
      expect(
        await checkerOf(release(prerelease: true))
            .check(currentVersion: '2.0.0'),
        isNull,
      );
    });

    test(
      'skip this version mutes the current one and returns with the next',
      () async {
        final c = checkerOf(release());
        expect(
          await c.check(currentVersion: '2.0.0', skippedVersion: '2.1.0'),
          isNull,
        );
        // A release newer than the skipped one appears: skipping is not a
        // permanent disable.
        final next = checkerOf(release(tag: 'v2.2.0'));
        final r = await next.check(
          currentVersion: '2.0.0',
          skippedVersion: '2.1.0',
        );
        expect(r!.tag, 'v2.2.0');
      },
    );

    test('a local version that cannot be read means no check', () async {
      expect(await checkerOf(release()).check(currentVersion: 'dev'), isNull);
    });
  });

  group('fail-safe', () {
    test(
      '**the guard**: any network failure returns null and never throws',
      () async {
        // The repository is private today, so GitHub answers 404 on every
        // automatic check. Throwing here would mean an error message in the
        // user's face at every launch.
        final c = UpdateChecker(
          fetch: (_) async => throw Exception('404'),
          assetMarker: 'super',
        );
        expect(await c.check(currentVersion: '2.0.0'), isNull);
      },
    );

    test(
      '**the guard**: the manual check tells up to date apart from unreachable',
      () async {
        // In `check` the two results are both `null`, so a manual button
        // built on it would say "you are on the latest version" while the
        // network was down.
        final broken = UpdateChecker(
          fetch: (_) async => throw Exception('offline'),
          assetMarker: 'super',
        );
        await expectLater(
          broken.checkOrThrow(currentVersion: '2.0.0'),
          throwsA(anything),
        );

        final same = checkerOf(release(tag: 'v2.0.0'));
        expect(await same.checkOrThrow(currentVersion: '2.0.0'), isNull);
      },
    );

    test('malformed or unexpected JSON returns null', () async {
      for (final body in ['', 'not json', '[]', '{}', '{"tag_name":123}']) {
        expect(
          await checkerOf(body).check(currentVersion: '2.0.0'),
          isNull,
          reason: 'الجسم «$body»',
        );
      }
    });
  });

  group('isDue', () {
    final now = DateTime(2026, 9, 20, 12);

    test('it checks the first time, then honours the interval', () {
      expect(UpdateChecker.isDue(null, now), isTrue);
      expect(
        UpdateChecker.isDue(now.subtract(const Duration(hours: 1)), now),
        isFalse,
      );
      expect(
        UpdateChecker.isDue(now.subtract(const Duration(hours: 13)), now),
        isTrue,
      );
    });

    test('**the guard**: a clock that jumps backwards does not freeze the check forever', () {
      // A timezone change or an NTP sync can leave the last check "in the
      // future"; without this branch the difference stays negative and a
      // check is never due again.
      final future = now.add(const Duration(days: 400));
      expect(UpdateChecker.isDue(future, now), isTrue);
    });
  });
}
