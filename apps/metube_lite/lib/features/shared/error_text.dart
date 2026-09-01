import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// تحويل استثناءات النواة المصنفة إلى نص مترجم (TRD §3.3) —
/// **المكان الوحيد** الذي يترجم الأخطاء؛ لا نصوص أخطاء متناثرة.
String errorText(MTLocalizations l10n, Object error) => switch (error) {
      AuthFailureException() => l10n.errAuth,
      NotMeTubeServerException() => l10n.errNotMeTube,
      NoApiException() => l10n.errNoApi,
      NetworkException() => l10n.errNetwork,
      PlatformBlockedException() => l10n.errPlatformBlocked,
      PollTimeoutException() => l10n.errPollTimeout,
      UnsafeFilenameException() => l10n.errServer('unsafe filename'),
      ServerErrorException(:final detail) =>
        l10n.errServer(detail ?? '؟'),
      CancelledException() => l10n.cancel,
      _ => l10n.errorGeneric(error.toString()),
    };
