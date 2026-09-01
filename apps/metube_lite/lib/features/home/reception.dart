import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// م-2: رابط منصة معروفة جاهز في الحافظة ⇒ يتحول زر الإضافة لوضع
/// «الرابط جاهز للصق». يُفحص عند الإقلاع والعودة للتطبيق.
final clipboardUrlProvider = StateProvider<String?>((ref) => null);

Future<void> refreshClipboardUrl(Ref ref) async {
  String? found;
  try {
    final data = await Clipboard.getData('text/plain');
    final url = UrlKit.extractUrl(data?.text ?? '');
    if (url.startsWith('http') && MediaPlatform.isKnown(url)) found = url;
  } catch (_) {
    // بعض الأجهزة تمنع قراءة الحافظة بالخلفية — نتجاهل بصمت.
  }
  ref.read(clipboardUrlProvider.notifier).state = found;
}

/// م-3: استقبال المشاركة من أندرويد — حتى cold start، وعدة روابط دفعة.
/// يبث قوائم الروابط المستخرجة من أي نص مشارك.
class ShareReceiver {
  ShareReceiver({required this.onUrls});

  final void Function(List<String> urls) onUrls;
  StreamSubscription<List<SharedMediaFile>>? _subscription;

  Future<void> start() async {
    final initial = await ReceiveSharingIntent.instance.getInitialMedia();
    _handle(initial);
    await ReceiveSharingIntent.instance.reset();
    _subscription =
        ReceiveSharingIntent.instance.getMediaStream().listen(_handle);
  }

  void _handle(List<SharedMediaFile> shared) {
    final urls = <String>[];
    for (final media in shared) {
      if (media.type == SharedMediaType.text ||
          media.type == SharedMediaType.url) {
        urls.addAll(UrlKit.extractAllUrls(media.path));
      }
    }
    if (urls.isNotEmpty) onUrls(urls);
  }

  void dispose() => _subscription?.cancel();
}
