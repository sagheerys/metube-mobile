import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../library/library_actions.dart' show wifiOnlyRejection;

/// Turns the core's classified exceptions into translated text (TRD §3.3).
/// **The only place** errors are translated; there are no scattered error
/// strings.
String errorText(MTLocalizations l10n, Object error) => switch (error) {
  AuthFailureException() => l10n.errAuth,
  NotMeTubeServerException() => l10n.errNotMeTube,
  NoApiException() => l10n.errNoApi,
  // A refusal by the user's own choice ("Wi-Fi only") is not a network
  // fault. "Could not reach the server" here is a wrong diagnosis that
  // sends them hunting through their router.
  NetworkException(:final detail) when detail == wifiOnlyRejection =>
    l10n.waitingForWifi,
  NetworkException() => l10n.errNetwork,
  PlatformBlockedException() => l10n.errPlatformBlocked,
  PollTimeoutException() => l10n.errPollTimeout,
  UnsafeFilenameException() => l10n.errServer('unsafe filename'),
  ServerErrorException(:final detail) => l10n.errServer(detail ?? '؟'),
  CancelledException() => l10n.cancel,
  _ => l10n.errorGeneric(error.toString()),
};
