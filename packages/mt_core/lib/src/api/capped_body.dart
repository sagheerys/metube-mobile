import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'api_exceptions.dart';

/// Reads a streamed response body, giving up as soon as it passes
/// [maxBytes].
///
/// **Why streamed**: asking Dio for the bytes buffers the whole body before
/// anyone can look at its size, and its receive timeout restarts with every
/// chunk. A server that kept sending (a broken one, or a hostile one serving
/// gigabytes under a subtitle's name) filled the phone's memory while the
/// app waited to compare the total with a ceiling of a few megabytes. Here
/// the declared length is refused before reading, and an undeclared or false
/// one stops the transfer at the ceiling: [cancel] closes the connection.
Future<Uint8List> readCappedBody(
  ResponseBody body,
  int maxBytes,
  CancelToken cancel, {
  required String what,
}) async {
  final declared = int.tryParse(
    body.headers['content-length']?.firstOrNull ?? '',
  );
  if (declared != null && declared > maxBytes) {
    cancel.cancel();
    throw ServerErrorException('$what over $maxBytes bytes');
  }
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in body.stream) {
    bytes.add(chunk);
    if (bytes.length > maxBytes) {
      cancel.cancel();
      throw ServerErrorException('$what over $maxBytes bytes');
    }
  }
  return bytes.takeBytes();
}
