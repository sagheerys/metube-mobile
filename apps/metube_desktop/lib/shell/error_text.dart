import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// The core's classified failures in the user's language, as the phone
/// apps word them. The one place an error becomes a sentence.
String errorText(MTLocalizations l, Object error) => switch (error) {
  // Before its parent, and not the password: Cloudflare turned the
  // service token away.
  AccessRejectedException() => l.errAccessRejected,
  AuthFailureException() => l.errAuth,
  NotMeTubeServerException() => l.errNotMeTube,
  // Before its parent: a file gone from a working server is not a wrong
  // address.
  FileGoneException() => l.errFileGone,
  NoApiException() => l.errNoApi,
  NetworkException() => l.errNetwork,
  PlatformBlockedException() => l.errPlatformBlockedCookies,
  PollTimeoutException() => l.errPollTimeout,
  CookiesTooLargeException() => l.cookiesTooLarge,
  UnsafeFilenameException() => l.errServer('unsafe filename'),
  // The first sentence only, isolated, so yt-dlp's English is not cut and
  // reordered inside an Arabic line.
  ServerErrorException(:final detail) => l.errServer(
    detail == null ? '?' : mtName(serverReason(detail)),
  ),
  CancelledException() => l.cancel,
  _ => l.errorGeneric(error.toString()),
};

/// The server's own answer to a second follow of the same channel, which
/// it gives in English whatever the interface language.
bool isAlreadyFollowed(Object error) =>
    error is ServerErrorException &&
    (error.detail ?? '').toLowerCase().contains('already subscribed');
