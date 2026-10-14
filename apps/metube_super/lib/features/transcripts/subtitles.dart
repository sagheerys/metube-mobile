import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import 'transcripts_state.dart';

/// Subtitles over the video, drawn from the transcripts (owner's request
/// 2026-10-14): whether they show, how large, and whether the shorts get
/// them too. All off until asked for, so nothing changes for anyone who
/// does not want them.
class SubtitlePrefs {
  SubtitlePrefs(this._store) {
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

  static const scales = [0.85, 1.0, 1.25];
  static const _shownKey = 'subtitles_shown';
  static const _sizeKey = 'subtitles_size';
  static const _shortsKey = 'subtitles_in_shorts';

  double get scale => scales[size.value.clamp(0, scales.length - 1)];

  Future<void> _load() async {
    shown.value = await _store.getBool(_shownKey) ?? false;
    size.value = await _store.getInt(_sizeKey) ?? 1;
    inShorts.value = await _store.getBool(_shortsKey) ?? false;
    // Saved from here on; what was just read is not written back.
    shown.addListener(() => _store.setBool(_shownKey, shown.value));
    size.addListener(() => _store.setInt(_sizeKey, size.value));
    inShorts.addListener(() => _store.setBool(_shortsKey, inShorts.value));
  }

  void dispose() {
    shown.dispose();
    size.dispose();
    inShorts.dispose();
  }
}

final subtitlePrefsProvider = Provider<SubtitlePrefs>((ref) {
  final prefs = SubtitlePrefs(ref.watch(keyValueStoreProvider));
  ref.onDispose(prefs.dispose);
  return prefs;
});

/// A clip's subtitle lines, in the app's language where kept, else the
/// first other language kept (English, as the app keeps it). Null for a
/// clip without a transcript, or while transcripts are off. The same list
/// comes back until the transcripts change, so a player does not regroup
/// its sentences on every rebuild.
final subtitleLinesProvider = Provider.family<List<MTCaptionLine>?, String>((
  ref,
  url,
) {
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

  final best =
      (kept.toList()..sort((a, b) => rank(a.language) - rank(b.language)))
          .first;
  return [
    for (final s in best.segments)
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
  ];
});

/// What a player draws for [item]: its lines, shown as [shown] says.
MTCaptions? subtitlesFor(
  WidgetRef ref,
  PlaylistItem item, {
  ValueNotifier<bool>? shown,
}) {
  final lines = ref.read(subtitleLinesProvider(item.canonicalUrl));
  if (lines == null) return null;
  final prefs = ref.read(subtitlePrefsProvider);
  return MTCaptions(
    lines: lines,
    shown: shown ?? prefs.shown,
    scale: prefs.scale,
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
      listenable: Listenable.merge([prefs.shown, prefs.size, prefs.inShorts]),
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
          Text(l10n.subtitlesSize, style: text.bodyMedium),
          const SizedBox(height: MTSpace.xs),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 0, label: Text(l10n.subtitlesSizeSmall)),
              ButtonSegment(value: 1, label: Text(l10n.subtitlesSizeMedium)),
              ButtonSegment(value: 2, label: Text(l10n.subtitlesSizeLarge)),
            ],
            selected: {prefs.size.value},
            onSelectionChanged: (selection) =>
                prefs.size.value = selection.first,
          ),
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
