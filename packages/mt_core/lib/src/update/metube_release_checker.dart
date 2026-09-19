import 'dart:convert';

import '../resolvers/http_fetch.dart';

/// **The latest MeTube release, for telling the server owner their
/// container is behind.**
///
/// Separate from [UpdateChecker] on purpose, though both read GitHub
/// releases: that one is about **this app** — it compares app versions,
/// picks an APK asset by name and drives an installer. This one wants a
/// single string, has no asset and installs nothing. Sharing the code would
/// mean one class serving two jobs whose only likeness is the URL.
///
/// **Isolated from `MeTubeApiClient`** (rule 1): it borrows the same
/// [HttpGetString] the platform resolvers use, so the server's Basic Auth
/// header cannot travel to GitHub, and GitHub learns nothing about the
/// server.
///
/// **Fail-safe like every other GitHub read here:** no network, a rate
/// limit, an unexpected shape — all of them are `null`, which the interface
/// shows as "unknown" rather than as a failure. Nobody asked for this
/// information; it must never cost them an error.
class MeTubeReleaseChecker {
  const MeTubeReleaseChecker({required this.fetch, this.repo = metubeRepo});

  /// MeTube's own repository — the server this app is a client for.
  static const String metubeRepo = 'alexta69/metube';

  final HttpGetString fetch;
  final String repo;

  Uri get latestUri =>
      Uri.parse('https://api.github.com/repos/$repo/releases/latest');

  /// The newest release tag (`2026.09.15`), or null.
  ///
  /// The tag is returned **verbatim**, with no parsing and no comparison:
  /// deciding whether it is newer than a particular server belongs to
  /// [ServerVersion.isOlderThan], which knows how to refuse shapes it does
  /// not understand.
  Future<String?> latestTag() async {
    try {
      final decoded = json.decode(await fetch(latestUri));
      if (decoded is! Map) return null;
      final tag = decoded['tag_name'];
      if (tag is! String || tag.trim().isEmpty) return null;
      return tag.trim();
    } catch (_) {
      return null;
    }
  }
}
