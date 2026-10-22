import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

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
///
/// The share is held natively (`ShareInbox.kt`) until this side takes it.
/// Android calls `arrived` when one lands on a running app, and [start]
/// takes whatever landed before Dart was listening. The native side alone
/// decides what counts as a new share: a rebuilt activity carries the old
/// one, which used to open the previous clip instead of the one shared.
class ShareReceiver {
  ShareReceiver({required this.onUrls, this.onLog, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const channel = MethodChannel('metube/share');

  final void Function(List<String> urls) onUrls;

  /// A trace in the diagnostic log on every reception, **prompted by field
  /// report 2026-09-08**: "sometimes the download sheet only appears if I
  /// try again". Without this line there is no telling whether the app lost
  /// the link or it never arrived.
  final void Function(String message)? onLog;

  bool _disposed = false;

  /// The last batch delivered, so a platform that signals one share twice
  /// does not stack two sheets.
  List<String>? _lastDelivered;
  DateTime? _lastAt;
  final DateTime Function() _clock;

  /// How long a repeat counts as the same delivery. The double delivery
  /// comes within moments; a person sharing the same link again comes
  /// later, and means it (field report 2026-10-15: a link shared again
  /// after its sheet was closed was ignored without a word, however long
  /// after).
  static const repeatWindow = Duration(seconds: 3);

  /// **Listen first, then take** what is already waiting: a share landing
  /// between the two is still held natively, and its `arrived` call takes
  /// it, so there is no window in which it can be lost.
  Future<void> start() async {
    // **Early teardown:** a hot restart or a quick close left a live
    // listener holding a dead shell.
    if (_disposed) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'arrived') await _take();
    });
    await _take();
  }

  Future<void> _take() async {
    if (_disposed) return;
    List<String>? texts;
    try {
      texts = await channel.invokeListMethod<String>('take');
    } on MissingPluginException {
      // No native side: a platform with no share sheet.
      return;
    } on PlatformException catch (e) {
      onLog?.call('share take failed: ${e.code}');
      return;
    }
    if (_disposed || texts == null) return;
    _handle(texts);
  }

  void _handle(List<String> texts) {
    final urls = [for (final text in texts) ...UrlKit.extractAllUrls(text)];
    if (urls.isEmpty || _disposed) return;
    // The same batch twice means two sheets stacked, or two downloads of
    // one link.
    final now = _clock();
    if (_lastDelivered != null &&
        now.difference(_lastAt!) < repeatWindow &&
        _lastDelivered!.length == urls.length &&
        List.generate(
          urls.length,
          (i) => _lastDelivered![i] == urls[i],
        ).every((same) => same)) {
      onLog?.call('share duplicate ignored (${urls.length})');
      return;
    }
    _lastDelivered = urls;
    _lastAt = now;
    onLog?.call('share received: ${urls.length}');
    onUrls(urls);
  }

  /// The channel handler is left in place: a shell built before this one
  /// is torn down has already installed its own, and clearing it here
  /// would silence that one. A disposed receiver ignores every call.
  void dispose() {
    _disposed = true;
  }
}
