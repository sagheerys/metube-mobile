import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../../di.dart';

/// **What the server says about subscriptions**, in the one shape the
/// screen needs.
///
/// Null [subscriptions] is not an empty list: it is a MeTube older than
/// the feature (§2.7), and the screen says so rather than showing an
/// empty list that no button could ever fill.
class SubscriptionsState {
  const SubscriptionsState({required this.subscriptions});

  final List<ChannelSubscription>? subscriptions;

  bool get supported => subscriptions != null;

  /// Sorted for reading, not for the server: the ones that need attention
  /// first, then the paused ones last, then by name.
  List<ChannelSubscription> get sorted {
    final all = [...?subscriptions];
    all.sort((a, b) {
      if (a.hasError != b.hasError) return a.hasError ? -1 : 1;
      if (a.enabled != b.enabled) return a.enabled ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return all;
  }
}

/// The list, re-read on demand.
///
/// **Not polled.** The server checks channels on its own schedule, and
/// what it downloads arrives through `/history` like everything else, so
/// the library is already live without this provider refreshing. Asking
/// again is what the pull-to-refresh and every action do.
final subscriptionsProvider = FutureProvider<SubscriptionsState>((ref) async {
  final api = ref.watch(apiClientProvider);
  if (api == null) return const SubscriptionsState(subscriptions: null);
  return SubscriptionsState(subscriptions: await api.fetchSubscriptions());
});

/// The actions, kept out of the widgets so the screen stays a screen.
///
/// Every one of them **re-reads the list afterwards** instead of editing a
/// local copy: the server owns this state, it may refuse a change, and a
/// check that runs while the user watches changes fields nobody sent.
class SubscriptionsController {
  const SubscriptionsController(this._ref);

  final Ref _ref;

  MeTubeApi? get _api => _ref.read(apiClientProvider);

  /// Returns the channel's own title, as the server resolved it, so the
  /// confirmation can name what was followed rather than echo the URL the
  /// user pasted.
  Future<String?> follow(
    String url, {
    required Quality quality,
    required int checkIntervalMinutes,
    String? titleRegex,
  }) async {
    final api = _api;
    if (api == null) throw const NoApiException();
    final created = await api.subscribe(
      url,
      quality,
      checkIntervalMinutes: checkIntervalMinutes,
      compatibleVideo: _ref.read(settingsProvider).compatiblePlayback,
      titleRegex: titleRegex,
    );
    _reload();
    return created?.name;
  }

  Future<void> setEnabled(ChannelSubscription sub, bool enabled) async {
    await _api?.updateSubscription(sub.id, enabled: enabled);
    _reload();
  }

  Future<void> edit(
    ChannelSubscription sub, {
    String? name,
    int? checkIntervalMinutes,
    String? titleRegex,
    bool clearTitleRegex = false,
  }) async {
    await _api?.updateSubscription(
      sub.id,
      name: name,
      checkIntervalMinutes: checkIntervalMinutes,
      titleRegex: titleRegex,
      clearTitleRegex: clearTitleRegex,
    );
    _reload();
  }

  Future<void> unfollow(ChannelSubscription sub) async {
    await _api?.deleteSubscriptions([sub.id]);
    _reload();
  }

  /// A check can take as long as yt-dlp takes to walk the channel, so the
  /// caller is told it started and the list is re-read when it ends.
  Future<void> checkNow({ChannelSubscription? only}) async {
    await _api?.checkSubscriptions(ids: only == null ? null : [only.id]);
    _reload();
  }

  void _reload() => _ref.invalidate(subscriptionsProvider);
}

final subscriptionsControllerProvider = Provider<SubscriptionsController>(
  SubscriptionsController.new,
);

/// The intervals the sheet offers, in minutes. **Nothing under half an
/// hour**: the server clamps its own loop to a minute, but a channel
/// checked every minute is a channel whose feed is fetched 1,440 times a
/// day for the sake of a video that arrives weekly.
const subscriptionIntervals = <int>[30, 60, 180, 360, 720, 1440];
