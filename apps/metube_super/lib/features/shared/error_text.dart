import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../library/library_actions.dart' show wifiOnlyRejection;

/// تحويل استثناءات النواة المصنفة إلى نص مترجم (TRD §3.3) —
/// **المكان الوحيد** الذي يترجم الأخطاء؛ لا نصوص أخطاء متناثرة.
String errorText(MTLocalizations l10n, Object error) => switch (error) {
      AuthFailureException() => l10n.errAuth,
      NotMeTubeServerException() => l10n.errNotMeTube,
      NoApiException() => l10n.errNoApi,
      // م-42: الرفض بقرار المستخدم («Wi‑Fi فقط») ليس عطلاً في الشبكة —
      // «تعذّر الوصول للخادم» هنا تشخيص خاطئ يرسله يطارد راوتره.
      NetworkException(:final detail) when detail == wifiOnlyRejection =>
        l10n.waitingForWifi,
      NetworkException() => l10n.errNetwork,
      PlatformBlockedException() => l10n.errPlatformBlocked,
      PollTimeoutException() => l10n.errPollTimeout,
      UnsafeFilenameException() => l10n.errServer('unsafe filename'),
      ServerErrorException(:final detail) =>
        l10n.errServer(detail ?? '؟'),
      CancelledException() => l10n.cancel,
      _ => l10n.errorGeneric(error.toString()),
    };
