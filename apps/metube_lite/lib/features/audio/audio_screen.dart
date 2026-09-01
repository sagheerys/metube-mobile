import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../player/playback_providers.dart';
import '../playlists/playlist_dialogs.dart';

/// شاشة الصوت الكاملة (`/audio`) — المحتوى من mt_media، والمصغرات
/// وحفظ القائمة (م-38) من طبقة التطبيق.
class AudioScreen extends ConsumerWidget {
  const AudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(audioHandlerProvider);
    return MTAudioScreen(
      handler: handler,
      artwork: artworkBuilderFor(ref),
      onSaveQueueAsPlaylist: () => _saveQueue(context, ref, handler),
    );
  }

  Future<void> _saveQueue(
      BuildContext context, WidgetRef ref, MTAudioHandler handler) async {
    final name = await promptPlaylistName(context);
    if (name == null || !context.mounted) return;
    final saved = await saveQueueAsPlaylist(ref, name, handler.orderedItems);
    if (saved && context.mounted) {
      showMTSnack(context, context.mtl.queueSavedAsPlaylist,
          type: MTSnackType.success);
    }
  }
}
