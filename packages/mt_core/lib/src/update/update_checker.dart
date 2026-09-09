import '../constants/mt_constants.dart';
import '../resolvers/http_fetch.dart';
import 'app_version.dart';
import 'update_release.dart';

/// Checking for updates through GitHub Releases.
///
/// **Completely isolated from `MeTubeApiClient`** (rule 1): it uses the
/// same [HttpGetString] the platform resolvers use, so the server's
/// credential header never leaks to GitHub, and GitHub learns nothing
/// about the server.
///
/// **Entirely fail-safe**: every error path returns `null`. No network, no
/// private repository and no unexpected JSON ever shows the user an error
/// during an automatic check. An update is a service, not a duty.
class UpdateChecker {
  UpdateChecker({
    required this.fetch,
    required this.assetMarker,
    this.repo = MTConstants.updateRepo,
  });

  final HttpGetString fetch;

  /// The part of an APK filename that identifies this app: `super` or
  /// `lite`.
  final String assetMarker;

  /// `owner/name`. The single switching point if releases ever move to a
  /// public repository separate from the code.
  final String repo;

  Uri get latestUri =>
      Uri.parse('https://api.github.com/repos/$repo/releases/latest');

  /// Fail-safe: swallows every error and returns `null`. **For the
  /// automatic
  /// check**, which runs without the user's knowledge and must never
  /// interrupt them with an error.
  Future<UpdateRelease?> check({
    required String currentVersion,
    String? skippedVersion,
  }) async {
    try {
      return await checkOrThrow(
        currentVersion: currentVersion,
        skippedVersion: skippedVersion,
      );
    } catch (_) {
      return null;
    }
  }

  /// Throws when unreachable. **For the manual check only**: whoever
  /// pressed
  /// the button deserves to tell "you are on the latest version" apart from
  /// "GitHub could not be reached", and in [check] those are one result.
  ///
  /// Returns the available release if it is **genuinely newer** than
  /// [currentVersion], and `null` when there is nothing new.
  /// [skippedVersion]
  /// is what the user chose to skip; it stays muted while it is the newest,
  /// and returns with whatever follows it.
  Future<UpdateRelease?> checkOrThrow({
    required String currentVersion,
    String? skippedVersion,
  }) async {
    final current = AppVersion.tryParse(currentVersion);
    // **An unreadable local version means no check**: with no reference to
    // compare against, we could offer an "update" to something older than
    // what is installed.
    if (current == null) return null;

    final body = await fetch(latestUri);
    final release = UpdateRelease.tryParse(body, assetMarker: assetMarker);
    if (release == null) return null;
    if (release.version <= current) return null;

    final skipped = AppVersion.tryParse(skippedVersion);
    if (skipped != null && release.version <= skipped) return null;
    return release;
  }

  /// Is the automatic check due? Prevents a request at every launch.
  ///
  /// `null` in [lastCheck] means "never checked", so it checks immediately.
  static bool isDue(
    DateTime? lastCheck,
    DateTime now, {
    Duration interval = MTConstants.updateCheckInterval,
  }) {
    if (lastCheck == null) return true;
    // **The device clock can move backwards** (a timezone change, an NTP
    // sync): a check "in the future" must not freeze the feature forever.
    if (lastCheck.isAfter(now)) return true;
    return now.difference(lastCheck) >= interval;
  }
}
