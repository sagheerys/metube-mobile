import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/mt_media.dart';

import '../../di.dart';
import '../library/library_providers.dart';
import '../library/widgets/item_details_sheet.dart';
import '../player/playback_providers.dart';

/// The full audio screen in Super (`/audio`): the content comes from
/// mt_media, and the clip details from the app layer, since mt_media does
/// not know the library indexes.
class AudioScreen extends ConsumerWidget {
  const AudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(audioHandlerProvider);
    return MTAudioScreen(
      handler: handler,
      artwork: artworkBuilderFor(ref),
      // **A details button instead of a queue button** (field report
      // 2026-09-05): the queue already has its visible button at the bottom
      // of
      // the screen.
      onDetails: () => _showDetails(context, ref, handler),
    );
  }

  void _showDetails(
    BuildContext context,
    WidgetRef ref,
    MTAudioHandler handler,
  ) {
    final key = handler.currentItem?.canonicalUrl;
    if (key == null) return;
    final items = ref.read(libraryItemsProvider).valueOrNull ?? const [];
    for (final candidate in items) {
      if (candidate.canonicalUrl == key) {
        showItemDetailsSheet(context, candidate);
        return;
      }
    }
  }
}
