import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// **The guard for the pre-publication audit, 2026-09-09.**
///
/// The captures under `test/fixtures/real/` come from live sites (rule 8),
/// and one of them arrived carrying credentials. The anonymisation pass
/// neutralised the first `track_authorization` token in
/// `soundcloud_set.html` and **missed the second**, which still held a real
/// signature, a request id and `"geo":"SA"` — the maintainer's country.
///
/// Reading a capture is easy; noticing the third token in a 200KB line is
/// not. So the rule is mechanical from here: any JWT that survives in a
/// fixture must carry a signature of nothing but `A`, which is what an
/// emptied signature looks like.
void main() {
  final dir = Directory('test/fixtures');

  // eyJ… is a base64url-encoded '{"' — the opening of every JWT header.
  final jwt = RegExp(
    r'eyJ[A-Za-z0-9_-]{8,}\.([A-Za-z0-9_-]{8,})\.([A-Za-z0-9_-]{8,})',
  );

  test('no fixture carries a live token', () {
    final offenders = <String>[];
    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      for (final m in jwt.allMatches(f.readAsStringSync())) {
        final signature = m.group(2)!;
        if (signature.split('').every((c) => c == 'A')) continue;
        offenders.add('${f.path}: ${_payload(m.group(1)!)}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'a fixture holds a token with a real signature; empty it the way '
          'the others are emptied rather than deleting the capture',
    );
  });
}

String _payload(String segment) {
  final padded = segment.padRight(segment.length + (-segment.length % 4), '=');
  try {
    return utf8.decode(base64Url.decode(padded));
  } on FormatException {
    return '(unreadable payload)';
  }
}
