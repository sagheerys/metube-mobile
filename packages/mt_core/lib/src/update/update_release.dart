import 'dart:convert';

import 'app_version.dart';

/// A release published on GitHub, as read from `releases/latest`.
class UpdateRelease {
  const UpdateRelease({
    required this.version,
    required this.tag,
    required this.apkUrl,
    required this.apkSize,
    this.notes = '',
    this.pageUrl = '',
    this.publishedAt,
  });

  final AppVersion version;
  final String tag;

  /// The download URL of the APK matching this app, Lite or Super.
  final String apkUrl;

  /// The file size in bytes, or `0` when the server did not declare one.
  final int apkSize;

  /// The release notes, raw Markdown as written.
  final String notes;

  /// The release page, a manual fallback when installing inside the app is
  /// not possible.
  final String pageUrl;

  final DateTime? publishedAt;

  /// The size in megabytes for display, or `null` when unknown.
  double? get sizeMb => apkSize <= 0 ? null : apkSize / (1024 * 1024);

  /// Reads GitHub's response and picks the asset matching [assetMarker].
  ///
  /// Returns `null` rather than throwing on any anomaly: a draft, a
  /// pre-release, a release with no APK for this app, or unexpected JSON.
  /// **An update check never troubles the user with an error** (rule 5: a
  /// new feature does not break what works).
  static UpdateRelease? tryParse(String body, {required String assetMarker}) {
    Object? decoded;
    try {
      decoded = json.decode(body);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;

    // **Drafts and pre-releases are rejected here too**, even though
    // `releases/latest` excludes them: the same parser serves the full
    // `releases` list if the endpoint ever changes.
    if (decoded['draft'] == true || decoded['prerelease'] == true) return null;

    final tag = decoded['tag_name'];
    if (tag is! String) return null;
    final version = AppVersion.tryParse(tag);
    if (version == null) return null;

    final assets = decoded['assets'];
    if (assets is! List) return null;
    final marker = assetMarker.toLowerCase();
    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final name = asset['name'];
      final url = asset['browser_download_url'];
      if (name is! String || url is! String) continue;
      final lower = name.toLowerCase();
      // **Matching on both the marker and the extension**: one release
      // carries both apps' files, so without the marker a Lite user
      // installs Super.
      if (!lower.endsWith('.apk') || !lower.contains(marker)) continue;
      final size = asset['size'];
      return UpdateRelease(
        version: version,
        tag: tag,
        apkUrl: url,
        apkSize: size is int ? size : 0,
        notes: decoded['body'] is String ? decoded['body'] as String : '',
        pageUrl: decoded['html_url'] is String
            ? decoded['html_url'] as String
            : '',
        publishedAt: decoded['published_at'] is String
            ? DateTime.tryParse(decoded['published_at'] as String)
            : null,
      );
    }
    return null;
  }
}
