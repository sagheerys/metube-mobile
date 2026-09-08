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
  ShareReceiver({required this.onUrls, this.onLog});

  final void Function(List<String> urls) onUrls;

  /// أثرٌ في السجل التشخيصي عند كل استقبال — **مصدره بلاغ المالك
  /// 2026-09-08**: «أحياناً لا تظهر ورقة التحميل إلا بإعادة المحاولة».
  /// بلا هذا السطر لا يُعرف أضاع التطبيقُ الرابطَ أم لم يصل أصلاً.
  final void Function(String message)? onLog;

  StreamSubscription<List<SharedMediaFile>>? _subscription;

  bool _disposed = false;

  /// آخر دفعة سُلِّمت — الرابط الأولي قد يصل **مرتين**: من
  /// `getInitialMedia` ومن البثّ معاً بعد أن صار الاشتراك أسبق.
  List<String>? _lastDelivered;

  /// **الاشتراك أولاً، ثم الرابط الأولي** (بلاغ المالك 2026-09-08).
  ///
  /// كان الترتيب معكوساً: `getInitialMedia` ← `reset` ← `listen`. وبين
  /// الانتظارين نافذةٌ **بلا مستمع**؛ والتطبيق الساكن في الخلفية
  /// يُسلَّم رابطه إلى البثّ مباشرة، فيسقط فيها بلا أثر — ثم تنجح
  /// إعادة المحاولة لأن الاشتراك صار قائماً. وهو ما وصفه المالك حرفياً.
  Future<void> start() async {
    // **تفكيك مبكر أثناء الانتظار (إصلاح م-1):** hot restart أو إغلاق
    // سريع كان يترك مستمعاً حياً يمسك غلافاً ميتاً.
    if (_disposed) return;
    _subscription =
        ReceiveSharingIntent.instance.getMediaStream().listen(_handle);

    final initial = await ReceiveSharingIntent.instance.getInitialMedia();
    if (_disposed) return;
    _handle(initial);
    await ReceiveSharingIntent.instance.reset();
  }

  void _handle(List<SharedMediaFile> shared) {
    final urls = <String>[];
    for (final media in shared) {
      if (media.type == SharedMediaType.text ||
          media.type == SharedMediaType.url) {
        urls.addAll(UrlKit.extractAllUrls(media.path));
      }
    }
    if (urls.isEmpty || _disposed) return;
    // نفس الدفعة مرتين ⇒ ورقتان فوق بعضهما أو تنزيلان لرابط واحد.
    if (_lastDelivered != null &&
        _lastDelivered!.length == urls.length &&
        List.generate(urls.length, (i) => _lastDelivered![i] == urls[i])
            .every((same) => same)) {
      onLog?.call('share duplicate ignored (${urls.length})');
      return;
    }
    _lastDelivered = urls;
    onLog?.call('share received: ${urls.length}');
    onUrls(urls);
  }

  void dispose() {
    _disposed = true;
    _subscription?.cancel();
  }
}
