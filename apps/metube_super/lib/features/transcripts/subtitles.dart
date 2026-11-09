import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import 'subtitle_style.dart';
import 'transcripts_state.dart';

/// Subtitles over the video, drawn from the transcripts: whether they show, how
/// large, and whether the shorts get them too. All off until asked for, so
/// nothing changes for anyone who does not want them.
class SubtitlePrefs {
  SubtitlePrefs(this._store) {
    size.addListener(() => liveScale.value = scale);
    background.addListener(() => liveBackground.value = backdrop);
    _load();
  }

  final KeyValueStore _store;

  /// Shared by the CC button and the switch in settings.
  final shown = ValueNotifier(false);

  /// Small, medium, large: an index into [scales].
  final size = ValueNotifier(1);

  /// Many shorts carry their own words in the picture, so they are left
  /// alone unless asked.
  final inShorts = ValueNotifier(false);

  /// The language picked with the player's switch, kept from clip to clip;
  /// null is the app's language first.
  final language = ValueNotifier<String?>(null);

  /// Dark, light or no background: an index into
  /// [MTCaptionBackground.values].
  final background = ValueNotifier(0);

  /// The chapters under the player's buttons folded away, kept from clip
  /// to clip for someone who would rather not see them.
  final chaptersFolded = ValueNotifier(false);

  static const scales = [0.85, 1.0, 1.25];
  static const _shownKey = 'subtitles_shown';
  static const _sizeKey = 'subtitles_size';
  static const _shortsKey = 'subtitles_in_shorts';
  static const _languageKey = 'subtitles_language';
  static const _backgroundKey = 'subtitles_background';
  static const _chaptersFoldedKey = 'chapters_folded';

  double get scale => scales[size.value.clamp(0, scales.length - 1)];

  /// [scale] and [backdrop] as values a playing clip follows, so a change
  /// made over the picture (a long press on CC) shows at once.
  late final ValueNotifier<double> liveScale = ValueNotifier(scale);
  late final ValueNotifier<MTCaptionBackground> liveBackground = ValueNotifier(
    backdrop,
  );

  MTCaptionBackground get backdrop =>
      MTCaptionBackground.values[background.value.clamp(
        0,
        MTCaptionBackground.values.length - 1,
      )];

  /// Reads the store again, after a restored backup has rewritten it. The
  /// same notifiers are kept: the players are listening to them.
  Future<void> reload() async {
    shown.value = await _store.getBool(_shownKey) ?? false;
    size.value = await _store.getInt(_sizeKey) ?? 1;
    inShorts.value = await _store.getBool(_shortsKey) ?? false;
    language.value = await _store.getString(_languageKey);
    background.value = await _store.getInt(_backgroundKey) ?? 0;
    chaptersFolded.value = await _store.getBool(_chaptersFoldedKey) ?? false;
  }

  Future<void> _load() async {
    await reload();
    // Saved from here on; what was just read is not written back.
    shown.addListener(() => _store.setBool(_shownKey, shown.value));
    size.addListener(() => _store.setInt(_sizeKey, size.value));
    inShorts.addListener(() => _store.setBool(_shortsKey, inShorts.value));
    language.addListener(
      () => switch (language.value) {
        final code? => _store.setString(_languageKey, code),
        null => _store.remove(_languageKey),
      },
    );
    background.addListener(
      () => _store.setInt(_backgroundKey, background.value),
    );
    chaptersFolded.addListener(
      () => _store.setBool(_chaptersFoldedKey, chaptersFolded.value),
    );
  }

  void dispose() {
    shown.dispose();
    size.dispose();
    inShorts.dispose();
    language.dispose();
    background.dispose();
    chaptersFolded.dispose();
    liveScale.dispose();
    liveBackground.dispose();
  }
}

final subtitlePrefsProvider = Provider<SubtitlePrefs>((ref) {
  final prefs = SubtitlePrefs(ref.watch(keyValueStoreProvider));
  ref.onDispose(prefs.dispose);
  return prefs;
});

/// Every language a clip's subtitles come in, by code, the app's language
/// first and then the order the app keeps them in (English after). Null
/// for a clip without a transcript, or while transcripts are off. The same
/// map comes back until the transcripts change, so a player does not
/// regroup its sentences on every rebuild.
final subtitleTracksProvider =
    Provider.family<Map<String, List<MTCaptionLine>>?, String>((ref, url) {
      if (!(ref.watch(transcriptsEnabledProvider).valueOrNull ?? false)) {
        return null;
      }
      ref.watch(transcriptsRevisionProvider);
      final kept = ref
          .watch(transcriptIndexProvider)
          .valueOrNull
          ?.transcriptsFor(url);
      if (kept == null || kept.isEmpty) return null;
      final order = ref.read(transcriptsServiceProvider).languages;
      int rank(String language) {
        final at = order.indexOf(language);
        return at < 0 ? order.length : at;
      }

      return {
        for (final t
            in kept.toList()
              ..sort((a, b) => rank(a.language) - rank(b.language)))
          t.language: [
            for (final s in t.segments)
              MTCaptionLine(
                start: s.start,
                end: s.end,
                text: s.text,
                words: switch (s.words) {
                  final words? => [
                    for (final w in words) MTCaptionWord(w.start, w.text),
                  ],
                  null => null,
                },
              ),
          ],
      };
    });

/// A clip's subtitle lines in the language shown first.
final subtitleLinesProvider = Provider.family<List<MTCaptionLine>?, String>(
  (ref, url) => ref.watch(subtitleTracksProvider(url))?.values.first,
);

/// [tracks] as a player is given them: null when the clip keeps only
/// languages outside [order] (the reader's, then English) and none of them
/// is [chosen] with the switch. Another language is never switched on
/// unasked (owner's decision 2026-11-04).
Map<String, List<MTCaptionLine>>? offeredTracks(
  Map<String, List<MTCaptionLine>>? tracks, {
  required List<String> order,
  required String? chosen,
}) {
  if (tracks == null) return null;
  final wanted = tracks.keys.any((l) => l == chosen || order.contains(l));
  return wanted ? tracks : null;
}

/// What a player draws for [item]: its lines in every language it has,
/// shown as [shown] says.
MTCaptions? subtitlesFor(
  WidgetRef ref,
  PlaylistItem item, {
  ValueNotifier<bool>? shown,
}) {
  final prefs = ref.read(subtitlePrefsProvider);
  final tracks = offeredTracks(
    ref.read(subtitleTracksProvider(item.canonicalUrl)),
    order: ref.read(transcriptsServiceProvider).languages,
    chosen: prefs.language.value,
  );
  if (tracks == null) return null;
  return MTCaptions(
    lines: tracks.values.first,
    tracks: tracks,
    language: prefs.language,
    shown: shown ?? prefs.shown,
    scale: prefs.scale,
    background: prefs.backdrop,
    liveScale: prefs.liveScale,
    liveBackground: prefs.liveBackground,
    onAdjust: (context) => showSubtitleStyleSheet(context, prefs),
  );
}

/// The subtitle settings, under the transcripts while they are on.
class SubtitleSettings extends ConsumerWidget {
  const SubtitleSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final text = Theme.of(context).textTheme;
    final prefs = ref.watch(subtitlePrefsProvider);
    return ListenableBuilder(
      listenable: Listenable.merge([
        prefs.shown,
        prefs.size,
        prefs.background,
        prefs.inShorts,
      ]),
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: MTSpace.md),
          Text(l10n.subtitles, style: text.titleSmall),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.subtitlesShow, style: text.bodyMedium),
            subtitle: Text(l10n.subtitlesShowHelp, style: text.bodySmall),
            value: prefs.shown.value,
            onChanged: (on) => prefs.shown.value = on,
          ),
          SubtitleStyleChoices(prefs: prefs),
          const SizedBox(height: MTSpace.xs),
          Text(l10n.subtitlesStyleTip, style: text.bodySmall),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.subtitlesInShorts, style: text.bodyMedium),
            subtitle: Text(l10n.subtitlesInShortsHelp, style: text.bodySmall),
            value: prefs.inShorts.value,
            onChanged: (on) => prefs.inShorts.value = on,
          ),
        ],
      ),
    );
  }
}
