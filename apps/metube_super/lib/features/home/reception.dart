import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// A known-platform link waiting in the clipboard switches the add button
/// to its "link ready to paste" state. Checked at startup and when the app
/// returns to the foreground.
final clipboardUrlProvider = StateProvider<String?>((ref) => null);

Future<void> refreshClipboardUrl(Ref ref) async {
  String? found;
  try {
    final data = await Clipboard.getData('text/plain');
    final url = UrlKit.extractUrl(data?.text ?? '');
    if (url.startsWith('http') && MediaPlatform.isKnown(url)) found = url;
  } catch (_) {
    // Some devices forbid reading the clipboard in the background; we
    // ignore that silently.
  }
  ref.read(clipboardUrlProvider.notifier).state = found;
}

/// Receiving a share from Android, including on a cold start and with
/// several links at once. It broadcasts the lists of URLs extracted from
/// any shared text.
class ShareReceiver {
  ShareReceiver({required this.onUrls, this.onLog});

  final void Function(List<String> urls) onUrls;

  /// A trace in the diagnostic log on every reception, **prompted by field
  /// report 2026-09-08**: "sometimes the download sheet only appears if I
  /// try again". Without this line there is no telling whether the app lost
  /// the link or it never arrived.
  final void Function(String message)? onLog;

  StreamSubscription<List<SharedMediaFile>>? _subscription;

  bool _disposed = false;

  /// The last batch delivered. The initial link can arrive **twice** — from
  /// `getInitialMedia` and from the stream together — now that the
  /// subscription comes first.
  List<String>? _lastDelivered;

  /// **Subscribe first, then read the initial link** (field report
  /// 2026-09-08).
  ///
  /// The order used to be reversed: `getInitialMedia`, `reset`, `listen`,
  /// and between the two awaits there was a window **with no listener**. An
  /// app resting in the background has its link delivered straight to the
  /// stream, so it fell into that window without a trace, and then a retry
  /// succeeded because the subscription was by then in place. Which is
  /// exactly what was reported.
  Future<void> start() async {
    // **Early teardown during the await:** a hot restart or a
    // quick close left a live listener holding a dead shell.
    if (_disposed) return;
    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      _handle,
    );

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
    // The same batch twice means two sheets stacked, or two downloads of
    // one link.
    if (_lastDelivered != null &&
        _lastDelivered!.length == urls.length &&
        List.generate(
          urls.length,
          (i) => _lastDelivered![i] == urls[i],
        ).every((same) => same)) {
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
