import 'dart:convert';
import 'dart:io';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// The update downloads a file and installs it (runs it, on Windows), so
/// the file comes from GitHub over https or there is no update.
void main() {
  // `releases/latest` as GitHub answered it for 2.6.0 (2026-11-05),
  // trimmed to the fields the app reads.
  final real = File('test/fixtures/github_release_2_6_0.json')
      .readAsStringSync();

  test("each app reads its own file's hash from a real release, and a "
      'release without hashes still updates', () {
    // GitHub's API, as it answered for v2.7.0 on 2026-11-10.
    final v270 = File('test/fixtures/github_release_2_7_0.json')
        .readAsStringSync();
    String? hash(String marker, String ending) => UpdateRelease.tryParse(
      v270,
      assetMarker: marker,
      extension: ending,
    )?.sha256;
    expect(
      hash('Ember', '.exe'),
      'a39d2db355eeb092b661b3eca15e4c6acb19913ec3579d5e769c21d1df1bc78c',
    );
    expect(hash('Lite', '.apk'), startsWith('6181aaf5'));
    expect(hash('Super', '.apk'), startsWith('a61db2b1'));
    // v2.6.0 was read before GitHub listed hashes: no hash, same update.
    final old = UpdateRelease.tryParse(real, assetMarker: 'Lite');
    expect(old, isNotNull);
    expect(old!.sha256, isNull);
  });

  String moved(String Function(String url) to, {String? page}) {
    final json = jsonDecode(real) as Map<String, dynamic>;
    for (final asset in json['assets'] as List) {
      final a = asset as Map<String, dynamic>;
      a['browser_download_url'] = to(a['browser_download_url'] as String);
    }
    if (page != null) json['html_url'] = page;
    return jsonEncode(json);
  }

  test('the published release is taken as it is: the update still works', () {
    final r = UpdateRelease.tryParse(real, assetMarker: 'lite')!;
    expect(r.version.toString(), '2.6.0');
    expect(r.apkUrl, startsWith('https://github.com/sagheerys/'));
    expect(
      r.pageUrl,
      'https://github.com/sagheerys/metube-mobile/releases/tag/v2.6.0',
    );
    expect(UpdateRelease.tryParse(real, assetMarker: 'super'), isNotNull);
  });

  test('**the guard**: a file anywhere but GitHub over https is no '
      'update', () {
    for (final to in <String Function(String)>[
      (u) => u.replaceFirst('https://', 'http://'),
      (u) => u.replaceFirst('github.com', 'evil.example'),
      (u) => u.replaceFirst(
        'https://github.com',
        'https://github.com.evil.example',
      ),
      (_) => 'file:///C:/Windows/System32/calc.exe',
    ]) {
      expect(
        UpdateRelease.tryParse(moved(to), assetMarker: 'lite'),
        isNull,
        reason: moved(to),
      );
    }
  });

  test('a release page elsewhere is not opened', () {
    final r = UpdateRelease.tryParse(
      moved((u) => u, page: 'file:///C:/x.exe'),
      assetMarker: 'lite',
    );
    expect(r!.pageUrl, '');
  });
}
