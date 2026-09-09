/// Classified error types thrown by the core. The app turns them into
/// translated text at display time (`02-TRD.md` §3.3: no interface strings
/// in the core).
sealed class MTApiException implements Exception {
  const MTApiException([this.detail]);

  /// An optional technical detail, the raw server message. For logs, not
  /// for
  /// direct display.
  final String? detail;

  /// Should this be retried automatically when the network returns?
  ///
  /// **Yes for a broken road, no for a refusal at the destination.** A
  /// dropped connection and a poll timeout are incidents the network itself
  /// repairs. Wrong credentials, a blocked platform or an explicit server
  /// error are decisions by the other side: repeating them unchanged fails
  /// again and floods the server with doomed requests.
  bool get isRetryable =>
      this is NetworkException || this is PollTimeoutException;

  @override
  String toString() =>
      detail == null ? runtimeType.toString() : '$runtimeType: $detail';
}

/// 401: the Basic Auth credentials are wrong.
final class AuthFailureException extends MTApiException {
  const AuthFailureException([super.detail]);
}

/// A 200 response that is not JSON carrying both `done` and `queue`,
/// usually HTML.
final class NotMeTubeServerException extends MTApiException {
  const NotMeTubeServerException([super.detail]);
}

/// 404: the address responds, but there is no MeTube API on it.
final class NoApiException extends MTApiException {
  const NoApiException([super.detail]);
}

/// Unreachable: a drop, a timeout, DNS, a certificate.
final class NetworkException extends MTApiException {
  const NetworkException([super.detail]);
}

/// The server answered with an explicit error, in an `error` or `msg`
/// field or as an HTTP error status.
final class ServerErrorException extends MTApiException {
  const ServerErrorException([super.detail]);
}

/// A server error whose text indicates a blocked platform (login, sign in,
/// cookie, bot), so the interface offers to refresh cookies.
final class PlatformBlockedException extends ServerErrorException {
  const PlatformBlockedException([super.detail]);
}

/// A filename from the server failed the path safety guard: `..`, a
/// separator, or empty.
final class UnsafeFilenameException extends MTApiException {
  const UnsafeFilenameException([super.detail]);
}

/// The task was cancelled by the user. Not an error to display.
final class CancelledException extends MTApiException {
  const CancelledException([super.detail]);
}

/// The `/history` poll ran out (120 x 5s) without the item completing.
final class PollTimeoutException extends MTApiException {
  const PollTimeoutException([super.detail]);
}

/// An unexpected local failure while running the task: filesystem,
/// permissions, space.
///
/// **Its cause was defect ع-2:** the download worker caught only
/// `MTApiException`, so any `FileSystemException` from renaming the
/// partial file escaped the pump. The task froze on "pulling" and **the
/// whole queue stopped with no message**. Everything unclassified is now
/// wrapped here, so a single task fails and the rest continue.
final class LocalFailureException extends MTApiException {
  const LocalFailureException([super.detail]);
}
