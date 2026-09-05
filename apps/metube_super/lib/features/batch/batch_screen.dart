import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../shared/error_text.dart';
import 'batch_providers.dart';

/// شاشة التحميل الدفعي (م-11 · ر-3): معاينة القائمة بمربعات اختيار،
/// مدة كل عنصر ومجموع المحدد، اختيار الجودة، ثم إدراج في الطابور.
class BatchScreen extends ConsumerStatefulWidget {
  const BatchScreen({super.key, required this.playlistUrl});

  final String playlistUrl;

  @override
  ConsumerState<BatchScreen> createState() => _BatchScreenState();
}

class _BatchScreenState extends ConsumerState<BatchScreen> {
  final Set<String> _selected = {};
  bool _initialised = false;
  Quality? _quality;

  /// اسم قائمة المصدر — تُجمَّع تحته العناصر في قائمة محفوظة واحدة.
  String? _playlistName;

  /// رابط الفيديو المفرد إن كان المُدخل `watch?v=…&list=…`.
  String? get _singleVideoUrl {
    final id = UrlKit.youtubeVideoId(widget.playlistUrl);
    return id == null ? null : 'https://www.youtube.com/watch?v=$id';
  }

  void _downloadSingle() {
    final l10n = context.mtl;
    final count = ref.read(batchSubmitterProvider).submit(
          [_singleVideoUrl!],
          ref.read(settingsProvider).quality,
        );
    if (count == 0) {
      showMTSnack(context, l10n.noServerTitle, type: MTSnackType.error);
      return;
    }
    context.go('/');
    showMTSnack(context, l10n.addedNToServer(1), type: MTSnackType.success);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final preview = ref.watch(playlistPreviewProvider(widget.playlistUrl));
    final kind = PlaylistDetector.detect(widget.playlistUrl);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.batchTitle),
        // **مخرج للرابط الغامض.** `watch?v=X&list=Y` هو فيديو **داخل**
        // قائمة: المشاركة من يوتيوب تحمل `list` كثيراً، فبعد أن صارت
        // القوائم تُقرأ فعلاً صار من السهل أن تجد نفسك أمام 200 عنصر
        // وأنت تريد واحداً. الزر يظهر فقط حين يكون في الرابط `v=`.
        actions: [
          if (_singleVideoUrl != null)
            TextButton(
              onPressed: _downloadSingle,
              child: Text(l10n.batchThisVideoOnly),
            ),
        ],
      ),
      floatingActionButton: preview.valueOrNull == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _submit,
              icon: const Icon(Icons.download_rounded),
              label: Text(l10n.batchDownloadSelected),
            ),
      body: preview.when(
        loading: () => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: MTSpace.md),
              Text(l10n.batchLoading,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        error: (e, _) => MTEmptyState(
          icon: Icons.error_outline_rounded,
          title: l10n.failedToLoadPlaylist,
          message: errorText(l10n, e),
          actionLabel: l10n.retry,
          onAction: () =>
              ref.invalidate(playlistPreviewProvider(widget.playlistUrl)),
        ),
        data: (data) => data == null || data.tracks.isEmpty
            ? MTEmptyState(
                icon: Icons.playlist_remove_rounded,
                title: l10n.failedToLoadPlaylist,
                message: l10n.couldNotLoadPlaylist,
              )
            : _content(data, kind),
      ),
    );
  }

  /// ر-3 خطوة 2: إدراج المحدد ثم العودة للرئيسية.
  void _submit() {
    final l10n = context.mtl;
    if (_selected.isEmpty) {
      showMTSnack(context, l10n.batchNothingSelected, type: MTSnackType.error);
      return;
    }
    final count = ref.read(batchSubmitterProvider).submit(
          _selected.toList(),
          _quality ?? Quality.best,
          groupName: _playlistName,
          saveToDevice: ref.read(settingsProvider).saveBatchToDevice,
        );
    if (count == 0) {
      showMTSnack(context, l10n.noServerTitle, type: MTSnackType.error);
      return;
    }
    context.go('/');
    showMTSnack(context, l10n.addedNToServer(count),
        type: MTSnackType.success);
  }

  Widget _content(PlaylistPreview preview, PlaylistKind kind) {
    if (!_initialised) {
      _initialised = true;
      _playlistName = preview.title;
      _selected.addAll(preview.tracks.map((t) => t.url));
      // SoundCloud صوت فقط (§4) — الجودة تُثبَّت ولا تُعرض.
      _quality = kind == PlaylistKind.soundcloud
          ? Quality.audio
          : ref.read(settingsProvider).quality;
    }
    final selectedTracks =
        preview.tracks.where((t) => _selected.contains(t.url)).toList();
    final total = selectedTracks.fold(
        Duration.zero, (sum, t) => sum + (t.duration ?? Duration.zero));

    return Column(
      children: [
        _Header(
          preview: preview,
          selectedCount: selectedTracks.length,
          totalDuration: total,
          allSelected: _selected.length == preview.tracks.length,
          onToggleAll: () => setState(() {
            if (_selected.length == preview.tracks.length) {
              _selected.clear();
            } else {
              _selected.addAll(preview.tracks.map((t) => t.url));
            }
          }),
        ),
        if (kind != PlaylistKind.soundcloud)
          _QualityRow(
            quality: _quality ?? Quality.best,
            youtubeOnly: kind == PlaylistKind.youtube,
            onChanged: (q) => setState(() => _quality = q),
          ),
        // **الألبوم على الجهاز** (طلب المالك 2026-09-03): Super يضيف
        // للسيرفر ولا يسحب (ر-2)، فكانت القائمة كلها تبقى هناك. المفتاح
        // يطبّق «إتاحة دون اتصال» (م-17) على كل عضو يكتمل، ويُحفظ اختياره
        // فلا يُعاد ضبطه مع كل ألبوم.
        SwitchListTile(
          value: ref.watch(
              settingsProvider.select((s) => s.saveBatchToDevice)),
          onChanged: (value) => ref
              .read(settingsProvider.notifier)
              .setSaveBatchToDevice(value),
          dense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: MTSpace.pagePad),
          secondary: const Icon(Icons.save_alt_rounded),
          title: Text(context.mtl.batchSaveToDevice),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
                MTSpace.pagePad, 0, MTSpace.pagePad, MTSpace.xxl),
            itemCount: preview.tracks.length,
            itemBuilder: (context, index) {
              final track = preview.tracks[index];
              return CheckboxListTile(
                value: _selected.contains(track.url),
                onChanged: (checked) => setState(() => checked == true
                    ? _selected.add(track.url)
                    : _selected.remove(track.url)),
                contentPadding: EdgeInsets.zero,
                title: Text(track.title,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: track.duration == null
                    ? null
                    : Text(mtFormatDuration(track.duration!)),
                secondary: track.thumbnail == null
                    ? null
                    : ClipRRect(
                        borderRadius:
                            BorderRadius.circular(MTRadius.thumb - 2),
                        child: CachedNetworkImage(
                          imageUrl: track.thumbnail!,
                          width: 64,
                          height: 40,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// نسخة محلية من التنسيق (mt_media ودجات فقط — لا نستورد شاشاته هنا).
String mtFormatDuration(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return d.inHours > 0 ? '${d.inHours}:$minutes:$seconds' : '$minutes:$seconds';
}

class _Header extends StatelessWidget {
  const _Header({
    required this.preview,
    required this.selectedCount,
    required this.totalDuration,
    required this.allSelected,
    required this.onToggleAll,
  });

  final PlaylistPreview preview;
  final int selectedCount;
  final Duration totalDuration;
  final bool allSelected;
  final VoidCallback onToggleAll;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          MTSpace.pagePad, MTSpace.sm, MTSpace.pagePad, MTSpace.sm),
      child: Row(
        children: [
          if (preview.coverUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(MTRadius.thumb),
              child: CachedNetworkImage(
                imageUrl: preview.coverUrl!,
                width: 68,
                height: 68,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          const SizedBox(width: MTSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(preview.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: MTSpace.xxs),
                Text(
                  '${l10n.batchSelectedOf(selectedCount, preview.tracks.length)}'
                  ' · ${mtFormatDuration(totalDuration)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall!
                      .copyWith(color: p.ink3),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onToggleAll,
            child: Text(allSelected ? l10n.deselectAll : l10n.selectAll),
          ),
        ],
      ),
    );
  }
}

class _QualityRow extends StatelessWidget {
  const _QualityRow({
    required this.quality,
    required this.youtubeOnly,
    required this.onChanged,
  });

  final Quality quality;
  final bool youtubeOnly;
  final ValueChanged<Quality> onChanged;

  @override
  Widget build(BuildContext context) {
    // القاعدة 2: الجودات الرقمية ليوتيوب فقط.
    final options =
        youtubeOnly ? Quality.values : [Quality.best, Quality.audio];
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: MTSpace.pagePad),
        children: [
          for (final option in options) ...[
            ChoiceChip(
              label: Text(option.wire),
              selected: option == quality,
              showCheckmark: false,
              onSelected: (_) => onChanged(option),
            ),
            const SizedBox(width: MTSpace.xs),
          ],
        ],
      ),
    );
  }
}
