/// Classified error types thrown by the core. The app turns them into
/// translated text at display time: the core holds no interface strings.
sealed class MTApiException implements Exception {
  const MTApiException([this.detail]);

  /// An optional technical detail, the raw server message. For logs, not
  /// for direct display.
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

/// Cloudflare Access refused the service token (the Client ID or the Client
/// Secret), or the token could not be sent at all.
///
/// Told apart from [AuthFailureException] because the fix is somewhere else:
/// the server's own password is not involved, and showing "wrong password"
/// sends the user to the wrong field. Like [AuthFailureException] it is not
/// retryable: repeating the same token fails the same way. **Its [detail]
/// never carries a header value**; the secret must not reach a log.
final class AccessRejectedException extends MTApiException {
  const AccessRejectedException([super.detail]);
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

/// 404 on a finished file: the server listed it as done, but it was gone
/// when asked for, deleted or moved in between. Downloading it again
/// fixes it, which a wrong address would not.
///
/// A kind of [NoApiException], so code that already treats a 404 on a file
/// as "not there" keeps doing so; only its wording differs.
final class FileGoneException extends NoApiException {
  const FileGoneException([super.detail]);
}

/// Unreachable: a drop, a timeout, DNS, a certificate.
final class NetworkException extends MTApiException {
  const NetworkException([super.detail]);
}

/// The server answered with an explicit error, in an `error` or `msg` field
/// or as an HTTP error status.
final class ServerErrorException extends MTApiException {
  const ServerErrorException([super.detail]);
}

/// A server error whose text indicates a blocked platform (login, sign in,
/// cookie, bot), so the interface offers to refresh cookies.
final class PlatformBlockedException extends ServerErrorException {
  const PlatformBlockedException([super.detail]);
}

/// A filename from the server failed the path safety guard: a separator,
/// a NUL, or a name that is exactly `.` or `..`.
final class UnsafeFilenameException extends MTApiException {
  const UnsafeFilenameException([super.detail]);
}

/// The task was cancelled by the user. Not an error to display.
final class CancelledException extends MTApiException {
  const CancelledException([super.detail]);
}

/// The `/history` poll ran out (`MTConstants.maxPollAttempts` × 5s) without
/// the item completing.
final class PollTimeoutException extends MTApiException {
  const PollTimeoutException([super.detail]);
}

/// An unexpected local failure while running the task: filesystem,
/// permissions, space.
///
/// **Its cause (found in the 2026-09-02 audit):** the download worker caught only
/// `MTApiException`, so any `FileSystemException` from renaming the partial
/// file escaped the pump. The task froze on "pulling" and **the whole queue
/// stopped with no message**. Everything unclassified is now wrapped here,
/// so a single task fails and the rest continue.
final class LocalFailureException extends MTApiException {
  const LocalFailureException([super.detail]);
}

/// **The cookies file is bigger than the server will take** (§2.8, 1MB).
///
/// Refused before the upload rather than after: a phone's upload is the
/// slowest link in the chain, and the answer is known in advance.
final class CookiesTooLargeException extends MTApiException {
  const CookiesTooLargeException([super.detail]);
}
