import 'package:flutter/services.dart';

/// وجهات اختصارات ضغطة الأيقونة المطولة (م-41).
enum AppShortcut {
  /// لصق رابط الحافظة وبدء تحميله.
  paste,

  /// المكتبة مصفّاة على ⚡ القِصار.
  shorts,

  /// المكتبة مصفّاة على الصوتيات.
  audio;

  static AppShortcut? parse(String? name) {
    for (final value in AppShortcut.values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

/// جسر قناة `consumeShortcut`.
///
/// **يُستهلك مرة واحدة** من الجانب الأصلي: الاختصار نية لحظية، وإبقاؤه
/// في النية يعيد تنفيذه عند كل عودة للتطبيق من المهام الأخيرة.
///
/// الوجهة تصل من **فعل** النية (`<pkg>.SHORTCUT_<NAME>`) لا من رابط —
/// أي `data` في النية يختطفها Flutter كمسار إقلاع فيرمي go_router
/// «Page Not Found» (خلل مصطاد على المحاكي 2026-09-02).
class AppShortcuts {
  const AppShortcuts({this.channelName = 'com.yasir.metubesuper/permissions'});

  final String channelName;

  Future<AppShortcut?> consume() async {
    try {
      final name = await MethodChannel(channelName)
          .invokeMethod<String>('consumeShortcut');
      return AppShortcut.parse(name);
    } on Object {
      // منصة بلا القناة (اختبارات، سطح مكتب) ⇒ لا اختصار.
      return null;
    }
  }
}
