import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

import '../library/library_models.dart';
import 'transcript_moment.dart';
import 'transcript_sheet.dart';
import 'transcripts_state.dart';

/// Opens a clip's whole transcript, with [query] lit wherever it was said.
///
/// Every line plays the clip from its second. [context] belongs to the
/// screen underneath, which outlives the sheet: a tap closes the sheet
/// first, then plays from there.
void showTranscriptSheet(BuildContext context, LibraryItem item, String query) {
  final container = ProviderScope.containerOf(context, listen: false);
  final transcripts = _transcriptsOf(container, item.canonicalUrl);
  if (transcripts.isEmpty) return;
  _open(
    context,
    (sheetContext) => TranscriptSheet(
      title: item.title,
      query: query,
      transcripts: transcripts,
      onMoment: (start) {
        Navigator.pop(sheetContext);
        playFromMoment(context, container.read, item, start);
      },
    ),
  );
}

/// Opens the transcript of the item [handler] is playing, following along:
/// the line being said is marked and kept in view, and a tap on any line
/// jumps there without leaving the player. It closes itself when the queue
/// moves on, rather than follow another item's time with the wrong words.
void showPlayingTranscript(
  BuildContext context,
  MTAudioHandler handler,
  PlaylistItem playing,
) => _openFollowing(
  context,
  playing,
  position: handler.positionStream,
  stillPlaying: () => handler.currentItem?.canonicalUrl == playing.canonicalUrl,
  seek: handler.seek,
);

/// The same, for the video [session] is playing.
void showVideoTranscript(
  BuildContext context,
  MTVideoSession session,
  PlaylistItem playing,
) => _openFollowing(
  context,
  playing,
  position: videoPositions(session),
  stillPlaying: () => session.current?.canonicalUrl == playing.canonicalUrl,
  seek: session.seek,
);

/// The transcript as a panel beside a full-screen video, for the items
/// that have one.
MTVideoPanel? Function(PlaylistItem item) transcriptPanels(
  BuildContext context,
  MTVideoSession session,
) {
  final container = ProviderScope.containerOf(context, listen: false);
  final label = context.mtl.transcript;
  return (item) {
    final transcripts = _transcriptsOf(container, item.canonicalUrl);
    if (transcripts.isEmpty) return null;
    return MTVideoPanel(
      icon: Icons.subject_rounded,
      label: label,
      builder: (context, close) => TranscriptSheet(
        title: item.title,
        query: '',
        transcripts: transcripts,
        position: videoPositions(session),
        stillPlaying: () => session.current?.canonicalUrl == item.canonicalUrl,
        onMoment: session.seek,
        onClose: close,
      ),
    );
  };
}

/// A video's position, sampled: the session tells its listeners of much
/// more than the time, and a quarter second is finer than any caption.
Stream<Duration> videoPositions(MTVideoSession session) =>
    Stream.periodic(const Duration(milliseconds: 250), (_) => session.position);

void _openFollowing(
  BuildContext context,
  PlaylistItem playing, {
  required Stream<Duration> position,
  required bool Function() stillPlaying,
  required Future<void> Function(Duration) seek,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  final transcripts = _transcriptsOf(container, playing.canonicalUrl);
  if (transcripts.isEmpty) return;
  _open(
    context,
    (_) => TranscriptSheet(
      title: playing.title,
      query: '',
      transcripts: transcripts,
      position: position,
      stillPlaying: stillPlaying,
      onMoment: seek,
    ),
  );
}

List<Transcript> _transcriptsOf(ProviderContainer container, String url) =>
    container.read(transcriptIndexProvider).valueOrNull?.transcriptsFor(url) ??
    const [];

void _open(BuildContext context, WidgetBuilder builder) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    // Keeps the handle out of the camera cutout; the bottom is padded by
    // the sheet itself, since this protects the top only.
    useSafeArea: true,
    builder: builder,
  );
}
