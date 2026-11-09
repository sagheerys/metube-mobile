// Measurement for Cloudflare Access. Run:
//   dart tool/redirect_header_probe.dart
//
// Question 1: does a custom request header travel with a redirect to
// ANOTHER host? Server A answers 302 to server B (a different port, which
// is a different origin); B reports what it received. Measured for Dart's
// plain `HttpClient` and for Dio's default redirect handling.
//
// Question 2: what does Dart do with a header VALUE it cannot send (a
// non-ASCII character, a line break)? The answer decides how a badly
// pasted Client Secret is reported.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

const _header = 'CF-Access-Client-Id';

Future<void> main() async {
  final seenByB = <String, String?>{};
  final b = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  b.listen((request) {
    seenByB['last'] = request.headers.value(_header);
    request.response
      ..statusCode = 200
      ..write('B')
      ..close();
  });
  final a = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  a.listen((request) {
    request.response
      ..statusCode = 302
      ..headers.set('location', 'http://127.0.0.1:${b.port}/')
      ..close();
  });
  final start = Uri.parse('http://127.0.0.1:${a.port}/');

  print('--- 1. custom header across a cross-origin 302');
  seenByB.clear();
  final http = HttpClient();
  final req = await http.getUrl(start);
  req.headers.set(_header, 'marker-httpclient');
  req.followRedirects = true;
  final res = await req.close();
  await res.drain<void>();
  print('HttpClient (followRedirects): B received "${seenByB['last']}"');
  http.close(force: true);

  seenByB.clear();
  final dio = Dio();
  final response = await dio.getUri<String>(
    start,
    options: Options(headers: {_header: 'marker-dio'}),
  );
  print(
    'Dio (default redirects): status ${response.statusCode}, '
    'B received "${seenByB['last']}"',
  );

  print('--- 2. header values Dart may refuse to send');
  for (final entry in {
    'non-ASCII (U+00E9)': 'caf\u00e9',
    'Arabic letter': '\u0633\u0631',
    'embedded line break': 'abc\r\ndef',
    'embedded LF only': 'abc\ndef',
    'NUL': 'abc\u0000def',
  }.entries) {
    await _tryDio(entry.key, entry.value, b.port);
    await _tryHttpClient(entry.key, entry.value, b.port);
  }

  dio.close(force: true);
  await a.close(force: true);
  await b.close(force: true);
  // Keep-alive sockets held by the clients above would otherwise keep the
  // process alive after the last line: the first run printed its results
  // and then never returned.
  exit(0);
}

Future<void> _tryDio(String label, String value, int port) async {
  try {
    final response = await Dio().get<String>(
      'http://127.0.0.1:$port/',
      options: Options(headers: {_header: value}),
    );
    print('Dio        [$label]: sent, status ${response.statusCode}');
  } on Object catch (e) {
    print('Dio        [$label]: ${e.runtimeType}: ${_short(e)}');
  }
}

Future<void> _tryHttpClient(String label, String value, int port) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port/'));
    req.headers.set(_header, value);
    final res = await req.close();
    await res.drain<void>();
    print('HttpClient [$label]: sent, status ${res.statusCode}');
  } on Object catch (e) {
    print('HttpClient [$label]: ${e.runtimeType}: ${_short(e)}');
  } finally {
    client.close(force: true);
  }
}

String _short(Object e) {
  final text = e.toString().replaceAll(RegExp(r'\s+'), ' ');
  return text.length > 140
      ? '${utf8.decode(utf8.encode(text.substring(0, 140)))}...'
      : text;
}
