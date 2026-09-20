/// **A channel the server watches on the user's behalf** (§2.7).
///
/// The app owns none of the mechanism: MeTube runs the check loop, keeps
/// the list of ids it has already seen, and queues whatever is new. This
/// class is the shape of one row in that list, and every field it carries
/// is one the interface actually shows — the server returns a dozen more
/// (codec, subtitles, sponsorblock, chapter templates) that belong to the
/// container's configuration rather than to a phone.
class ChannelSubscription {
  const ChannelSubscription({
    required this.id,
    required this.name,
    required this.url,
    required this.enabled,
    required this.checkIntervalMinutes,
    this.quality,
    this.titleRegex,
    this.seenCount = 0,
    this.lastChecked,
    this.error,
  });

  final String id;

  /// The channel's own title, as the server resolved it when subscribing.
  /// Renameable through `/subscriptions/update`.
  final String name;

  final String url;

  /// A paused subscription stays in the list and stops being checked.
  /// **Pausing rather than deleting is the safe retreat**: deleting throws
  /// away `seen_ids`, so re-subscribing later starts from "everything
  /// currently on the channel is already seen" and the gap is lost forever.
  final bool enabled;

  final int checkIntervalMinutes;

  /// The wire value (`best`, `1080`, `audio` …), kept as text because it is
  /// the server's word and the app only displays it.
  final String? quality;

  /// Only titles matching this are downloaded. Null means everything.
  final String? titleRegex;

  /// **How many ids the server knows about, not how many it downloaded.**
  /// It starts at the size of the channel, because subscribing marks the
  /// existing catalogue as seen (§2.7). Labelling this "downloaded" would
  /// tell someone who just subscribed that 214 files landed on their disk.
  final int seenCount;

  /// **Seconds, not milliseconds** — unlike `/history`'s `timestamp` (§2.7).
  final DateTime? lastChecked;

  /// The last check's failure, kept by the server until a check succeeds.
  final String? error;

  bool get hasError => error != null && error!.trim().isNotEmpty;

  ChannelSubscription copyWith({
    String? name,
    bool? enabled,
    int? checkIntervalMinutes,
    String? titleRegex,
    bool clearTitleRegex = false,
  }) => ChannelSubscription(
    id: id,
    name: name ?? this.name,
    url: url,
    enabled: enabled ?? this.enabled,
    checkIntervalMinutes: checkIntervalMinutes ?? this.checkIntervalMinutes,
    quality: quality,
    titleRegex: clearTitleRegex ? null : (titleRegex ?? this.titleRegex),
    seenCount: seenCount,
    lastChecked: lastChecked,
    error: error,
  );

  /// Returns null for anything that is not a usable row, so one malformed
  /// entry drops out of the list instead of taking the screen down with it.
  static ChannelSubscription? fromJson(dynamic decoded) {
    if (decoded is! Map) return null;
    final id = decoded['id'];
    final url = decoded['url'];
    if (id is! String || id.isEmpty) return null;
    if (url is! String || url.isEmpty) return null;
    final name = decoded['name'];
    return ChannelSubscription(
      id: id,
      // A server that lost the title still has a URL to show.
      name: name is String && name.trim().isNotEmpty ? name.trim() : url,
      url: url,
      // **Absent means enabled**: the field is only ever false when the
      // user paused it, and treating a missing value as paused would show
      // a working subscription as stopped.
      enabled: decoded['enabled'] != false,
      checkIntervalMinutes: _asInt(decoded['check_interval_minutes']) ?? 60,
      quality: _asText(decoded['quality']),
      titleRegex: _asText(decoded['title_regex']),
      seenCount: _asInt(decoded['seen_count']) ?? 0,
      lastChecked: _asEpochSeconds(decoded['last_checked']),
      error: _asText(decoded['error']),
    );
  }

  /// The array `GET /subscriptions` answers with. Anything that is not an
  /// array is **not an empty list but a refusal**: a proxy's HTML page and
  /// "this server has no subscriptions" must not look the same.
  static List<ChannelSubscription>? listFromJson(dynamic decoded) {
    if (decoded is! List) return null;
    return [for (final row in decoded) ?fromJson(row)];
  }

  static String? _asText(dynamic raw) {
    if (raw is! String) return null;
    final text = raw.trim();
    return text.isEmpty ? null : text;
  }

  static int? _asInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }

  /// Seconds since the epoch, as a float. Zero and negatives are "never
  /// checked" rather than 1970.
  static DateTime? _asEpochSeconds(dynamic raw) {
    final num? seconds = raw is num
        ? raw
        : (raw is String ? num.tryParse(raw.trim()) : null);
    if (seconds == null || seconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round());
  }

  @override
  String toString() => 'ChannelSubscription($id, $name, enabled: $enabled)';
}
