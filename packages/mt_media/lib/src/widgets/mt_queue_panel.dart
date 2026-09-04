import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../models/playlist_item.dart';
import 'mt_up_next_list.dart';

/// محتوى قائمة الانتظار — نفس المحتوى في الأشكال الثلاثة (م-38):
/// ورقة سفلية (صوتي) · قسم «التالي» (فيديو عمودي) · لوحة جانبية (عرضي).
/// في كلها زر «احفظ هذه القائمة» ورابط «عرض الكل ↩» — والزر يغيب
/// حين يكون المصدر قائمةً محفوظة أصلاً ([playlistName] غير فارغ).
class MTQueuePanel extends StatelessWidget {
  const MTQueuePanel({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelect,
    this.artwork,
    this.onSaveAsPlaylist,
    this.onShowAll,
    this.playlistName,
    this.dark = false,
    this.paused = false,
    this.nested = false,
  });

  /// العناصر بترتيب التشغيل الفعلي.
  final List<PlaylistItem> items;

  /// فهرس الحالي داخل [items].
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final MTArtworkBuilder? artwork;

  /// م-38: تحويل جلسة التشغيل الحالية لقائمة دائمة.
  final VoidCallback? onSaveAsPlaylist;

  /// م-38: القفز لتفاصيل القائمة في تبويبها.
  final VoidCallback? onShowAll;
  final String? playlistName;
  final bool dark;

  /// العنصر الحالي موقوف مؤقتاً — يُمرَّر لمؤشر التوازن فيسكن.
  final bool paused;

  /// **داخل أب قابل للتمرير؟** (بلاغ المالك 2026-09-02: «لا تستطيع تمرير
  /// قائمة الفيديوهات السفلية»). القائمة الداخلية كانت `shrinkWrap` بلا
  /// `physics`، أي مجرى تمرير مستقل بارتفاع محتواها بالضبط ⇒ لا مدى
  /// لديه ليتحرك، **ويبتلع السحب** فلا يصل للأب. الحل ليس إلغاء
  /// `shrinkWrap` بل تعطيل فيزياء الابن ليمرّر الأبُ الكلَّ.
  final bool nested;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final l10n = context.mtl;
    final ink = dark ? p.miniInk : p.ink;
    final muted = dark ? p.miniInkMuted : p.ink3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                playlistName == null
                    ? l10n.upNext
                    : l10n.upNextIn(playlistName!),
                style: text.titleMedium!.copyWith(color: ink),
              ),
            ),
            if (onShowAll != null)
              TextButton(
                onPressed: onShowAll,
                child: Text(
                  l10n.viewAllInPlaylists,
                  style: text.labelSmall!.copyWith(
                    color: p.accentInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        Text(
          l10n.queueItemsCount(items.length),
          style: text.labelSmall!.copyWith(color: muted),
        ),
        const SizedBox(height: MTSpace.xs),
        Flexible(
          child: MTUpNextList(
            items: items,
            currentIndex: currentIndex,
            artwork: artwork,
            dark: dark,
            paused: paused,
            shrinkWrap: true,
            physics: nested ? const NeverScrollableScrollPhysics() : null,
            onTap: onSelect,
          ),
        ),
        // **لا يُعرض والقائمة قائمةٌ محفوظة أصلاً** (بلاغ المالك
        // 2026-09-04: «الزر موجود في كل مكان حتى في قائمة التشغيل»).
        // [playlistName] غير فارغ ⇔ التشغيل انطلق من قائمة محفوظة،
        // فحفظها «كقائمة تشغيل» يصنع نسخة ثانية بلا معنى.
        if (onSaveAsPlaylist != null && playlistName == null) ...[
          const SizedBox(height: MTSpace.sm),
          MTSaveQueueButton(
            onTap: onSaveAsPlaylist!,
            label: l10n.saveQueueAsPlaylist,
          ),
        ],
      ],
    );
  }
}

/// «احفظ هذه القائمة كقائمة تشغيل» (م-38).
class MTSaveQueueButton extends StatelessWidget {
  const MTSaveQueueButton({
    super.key,
    required this.onTap,
    required this.label,
  });

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return Material(
      color: p.accentSoft,
      borderRadius: BorderRadius.circular(MTRadius.field),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MTRadius.field),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: MTSpace.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MTRadius.field),
            border: Border.all(color: p.accent.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.playlist_add_rounded, size: 17, color: p.accentInk),
              const SizedBox(width: MTSpace.xs),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium!
                    .copyWith(color: p.accentInk, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// يفتح ورقة قائمة الانتظار السفلية (شاشة الصوت والمشغل العمودي).
Future<void> showMTQueueSheet(
  BuildContext context, {
  required List<PlaylistItem> items,
  required int currentIndex,
  required ValueChanged<int> onSelect,
  MTArtworkBuilder? artwork,
  VoidCallback? onSaveAsPlaylist,
  VoidCallback? onShowAll,
  String? playlistName,
  Listenable? liveness,
  bool Function()? paused,
}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  builder: (sheetContext) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(MTSpace.pagePad),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
        ),
        // **الورقة تُبنى مرة ولا تعرف أن التشغيل توقّف** — لذلك
        // تُعاد بناؤها على [liveness] (جلسة الفيديو أو مُنبّه مشغل
        // الصوت)، وإلا بقي مؤشر التوازن يرقص على مقطع ساكن.
        child: _LiveQueue(
          liveness: liveness,
          builder: (context) => MTQueuePanel(
            items: items,
            currentIndex: currentIndex,
            artwork: artwork,
            playlistName: playlistName,
            paused: paused?.call() ?? false,
            onSaveAsPlaylist: onSaveAsPlaylist,
            onShowAll: onShowAll,
            onSelect: (index) {
              Navigator.of(sheetContext).pop();
              onSelect(index);
            },
          ),
        ),
      ),
    ),
  ),
);

/// يعيد بناء محتوى الورقة كلما تغيّرت [liveness] — أو مرة واحدة إن
/// لم يُمرَّر مصدر حياة.
class _LiveQueue extends StatelessWidget {
  const _LiveQueue({required this.builder, this.liveness});

  final WidgetBuilder builder;
  final Listenable? liveness;

  @override
  Widget build(BuildContext context) => liveness == null
      ? builder(context)
      : ListenableBuilder(
          listenable: liveness!,
          builder: (context, _) => builder(context),
        );
}
