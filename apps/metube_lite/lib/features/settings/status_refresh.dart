import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widgets/server_status_card.dart';

/// **بطاقة الحالة كانت تكذب** (فحص 2026-09-06): `serverStatusProvider`
/// مزوّد بلا `autoDispose` ولا مؤقّت — يُحسب مرة ويبقى محفوظاً، فلو
/// سقط السيرفر بعد آخر فحص بقيت البطاقة «متصل» حتى يضغط المستخدم ↻.
///
/// العودة إلى التطبيق أنسب لحظة لإعادة السؤال: رخيصة (طلب واحد)، وتقع
/// تماماً حين ينظر المستخدم إلى الشاشة. ولا نضيف مؤقتاً دورياً: فحصٌ
/// كل دقيقة يوقظ الشبكة بلا أن ينظر أحد.
final statusRefreshProvider = Provider<void>((ref) {
  final listener = AppLifecycleListener(onResume: () {
    ref.invalidate(serverStatusProvider);
  });
  ref.onDispose(listener.dispose);
});
