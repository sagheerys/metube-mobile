/// Every fixed number and list the core uses. The source is
/// `docs/plan/05-DATA-SCHEMA.md`; no network or download number is written
/// anywhere else.
abstract final class MTConstants {
  // Network timeouts (§1).
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Pulls only, where large files stream.
  static const Duration downloadReceiveTimeout = Duration(minutes: 30);
  static const Duration testConnectionTimeout = Duration(seconds: 10);

  /// A quick probe for endpoint switching (EndpointResolver).
  static const Duration probeTimeout = Duration(seconds: 4);

  /// **How long short-link resolution may hold up a routing decision**
  /// (field report 2026-09-08): deciding "playlist or single" waits on the
  /// network and the user waits with it, so past this limit the link is
  /// used
  /// as it is rather than freezing the interface.
  static const Duration routingResolveTimeout = Duration(seconds: 5);

  // Polling rhythm (§2.3).
  static const Duration pollInterval = Duration(seconds: 5);

  /// 120 x 5s, a ten-minute ceiling for one download pipeline.
  static const int maxPollAttempts = 120;

  /// Super's live interface refresh, only while something is active.
  static const Duration livePollInterval = Duration(seconds: 2);

  // Pulling and retrying (§2.4).
  static const int pullRetries = 3;
  static const List<Duration> pullRetryBackoff = [
    Duration(seconds: 3),
    Duration(seconds: 6),
  ];

  // The queue (§3).
  static const int maxConcurrentDownloads = 1;

  // Qualities (§2.2).
  static const List<String> qualityWireValues = [
    'best',
    '1080',
    '720',
    '480',
    'audio',
  ];

  // Local files (§2.4 and §5.3).
  static const String liteFolderName = 'MeTube_Lite';
  static const String superFolderName = 'MeTube_Super';
  static const int filenameTitleMaxLength = 80;
  static const String defaultMediaExtension = 'mp4';

  // Classifying blocked-platform errors (§2.3).
  static const List<String> platformBlockedMarkers = [
    'login',
    'sign in',
    'cookie',
    'bot',
  ];

  // Short links (§4).
  static const int maxRedirectHops = 8;

  /// Favourites are a hidden system tag inside TagsIndex: they enter the
  /// backup automatically and never appear among the user's own tags.
  static const String favoritesSystemTag = '__favorites__';

  // Self-update from GitHub.

  /// `owner/name` for the releases repository. **The single switching
  /// point.**
  ///
  /// The `releases/latest` endpoint requires a **public** repository: while
  /// it is private GitHub answers 404, which is read as "no update" in
  /// silence (fail-safe). To separate releases from the code, changing this
  /// one line to an independent public releases repository is enough.
  static const String updateRepo = 'sagheerys/metube-mobile';

  /// How often the automatic check runs. Checking at every launch floods
  /// GitHub for nothing, and releases arrive in weeks rather than hours.
  static const Duration updateCheckInterval = Duration(hours: 12);

  /// The update file's name in the app cache. Fixed, so the next download
  /// overwrites it instead of piling old APKs on the device.
  static const String updateApkFileName = 'update.apk';
}
