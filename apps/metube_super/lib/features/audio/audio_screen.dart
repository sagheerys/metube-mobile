import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/mt_media.dart';

import '../../di.dart';
import '../player/playback_providers.dart';

/// شاشة الصوت الكاملة في Super (`/audio`) — المحتوى من mt_media،
/// والمصغرات والقوائم من طبقة التطبيق.
class AudioScreen extends ConsumerWidget {
  const AudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MTAudioScreen(
        handler: ref.watch(audioHandlerProvider),
        artwork: artworkBuilderFor(ref),
      );
}
