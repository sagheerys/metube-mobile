import 'dart:convert';
import 'dart:io';

/// Loads a fixture from `test/fixtures/`; the tests run from the package
/// root.
Map<String, dynamic> loadFixture(String name) {
  final content = File('test/fixtures/$name').readAsStringSync();
  return json.decode(content) as Map<String, dynamic>;
}
