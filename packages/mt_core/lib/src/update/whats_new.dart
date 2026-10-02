import 'app_version.dart';
import 'update_checker.dart';
import 'update_prefs.dart';

/// What to show once after an update.
class WhatsNew {
  const WhatsNew({
    required this.version,
    required this.notes,
    required this.pageUrl,
  });

  final String version;

  /// The release notes as written, or empty when neither a saved copy nor
  /// the network had them; the sheet then offers the release page alone.
  final String notes;
  final String pageUrl;
}

/// **"What's new" once, after an update**: the app only ever showed the
/// newest release page, so someone who jumped two versions never saw the
/// one in between, and someone who updated from a browser saw nothing.
///
/// It stays out of the way: never on a fresh install, never twice for one
/// version, and never an error. Every failure means "nothing to show".
class WhatsNewService {
  WhatsNewService({required this.prefs, required this.checker});

  final UpdatePrefs prefs;
  final UpdateChecker checker;

  /// What to show for [currentVersion], or `null`.
  ///
  /// [upgraded] says whether Android installed this over an older copy. It
  /// matters once only: the first version with this feature has no record
  /// of a version seen, and without it every existing user would be taken
  /// for a new one and miss the notes.
  Future<WhatsNew?> pending({
    required String currentVersion,
    required bool upgraded,
  }) async {
    final current = AppVersion.tryParse(currentVersion);
    if (current == null) return null;
    final seen = AppVersion.tryParse(await prefs.lastSeenVersion());
    if (seen == null && !upgraded) {
      // A fresh install: this version is where the record starts.
      await markSeen(currentVersion);
      return null;
    }
    if (seen != null && current <= seen) return null;
    return of(currentVersion);
  }

  /// The notes of [version] whenever asked, from settings: the saved copy
  /// if it is this version's, else the release page. `null` only for an
  /// unreadable version.
  Future<WhatsNew?> of(String version) async {
    final parsed = AppVersion.tryParse(version);
    if (parsed == null) return null;
    final name = parsed.toString();
    final saved = await prefs.savedNotes();
    final notes = saved != null && AppVersion.tryParse(saved.$1) == parsed
        ? saved.$2
        : await checker.notesFor(name);
    return WhatsNew(
      version: name,
      notes: notes ?? '',
      pageUrl: checker.pageUrlOf(name),
    );
  }

  /// Called as the sheet is shown, so a version is shown once.
  Future<void> markSeen(String version) => prefs.setLastSeenVersion(version);
}
