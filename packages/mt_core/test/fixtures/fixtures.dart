import 'dart:convert';
import 'dart:io';

/// تحميل fixture من `test/fixtures/` — تُشغَّل الاختبارات من جذر الحزمة.
Map<String, dynamic> loadFixture(String name) {
  final content = File('test/fixtures/$name').readAsStringSync();
  return json.decode(content) as Map<String, dynamic>;
}
