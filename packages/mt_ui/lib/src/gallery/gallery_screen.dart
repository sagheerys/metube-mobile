import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';
import '../widgets/mt_download_progress_card.dart';
import '../widgets/mt_empty_state.dart';
import '../widgets/mt_fab.dart';
import '../widgets/mt_media_card.dart';
import '../widgets/mt_platform_chip.dart';
import '../widgets/mt_search_field.dart';
import '../widgets/mt_section_header.dart';
import '../widgets/mt_snackbar.dart';
import '../widgets/mt_url_input_sheet.dart';

/// معرض داخلي لفحص بوابة المرحلة 3: كل مكوّن بالثيمين والاتجاهين —
/// **ليس شاشة منتج**؛ نصوصه عينات ثابتة عمداً (خارج قاعدة arb).
class MTGalleryScreen extends StatelessWidget {
  const MTGalleryScreen({
    super.key,
    this.onToggleTheme,
    this.onToggleDirection,
    this.onToggleVariant,
  });

  final VoidCallback? onToggleTheme;
  final VoidCallback? onToggleDirection;
  final VoidCallback? onToggleVariant;

  @override
  Widget build(BuildContext context) {
    final x = MTThemeX.of(context);
    final p = x.palette;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'معرض وهج — ${x.variant == MTVariant.lite ? 'Lite' : 'Super'}'),
        actions: [
          IconButton(
              onPressed: onToggleVariant,
              tooltip: 'Lite/Super',
              icon: const Icon(Icons.swap_horiz_rounded)),
          IconButton(
              onPressed: onToggleDirection,
              tooltip: 'RTL/LTR',
              icon: const Icon(Icons.format_textdirection_r_to_l_rounded)),
          IconButton(
              onPressed: onToggleTheme,
              tooltip: 'ليل/نهار',
              icon: const Icon(Icons.dark_mode_rounded)),
        ],
      ),
      floatingActionButton: MTFab(
        label: 'إضافة رابط',
        onPressed: () => _openUrlSheet(context),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            MTSpace.pagePad, 0, MTSpace.pagePad, 120),
        children: [
          const MTSectionHeader(title: 'الطباعة', trailing: 'كوفي + Tajawal'),
          const SizedBox(height: MTSpace.md),
          Text('عنوان رئيسي بالكوفي', style: text.headlineLarge),
          Text('عنوان ورقة', style: text.titleLarge),
          Text('نص أساسي بخط Tajawal يجري مجرى السطور بارتياح — 13.5',
              style: text.bodyMedium),
          Text('نص ثانوي خافت 11.5', style: text.bodySmall),
          const SizedBox(height: MTSpace.xl),

          const MTSectionHeader(title: 'اللوحة', trailing: 'وهج'),
          const SizedBox(height: MTSpace.md),
          Wrap(
            spacing: MTSpace.xs,
            runSpacing: MTSpace.xs,
            children: [
              _Swatch('فعل', p.accent),
              _Swatch('soft', p.accentSoft, ink: p.accentInk),
              _Swatch('زيتوني', p.offlineSoft, ink: p.offlineInk),
              _Swatch('مفضلة', p.favoriteSoft, ink: p.favorite),
              _Swatch('نجاح', p.ok),
              _Swatch('خطأ', p.err),
            ],
          ),
          const SizedBox(height: MTSpace.xl),

          const MTSectionHeader(title: 'البحث والرقاقات'),
          const SizedBox(height: MTSpace.md),
          const MTSearchField(hint: 'ابحث في المكتبة…'),
          const SizedBox(height: MTSpace.md),
          Wrap(
            spacing: MTSpace.xs,
            children: [
              ChoiceChip(
                  label: const Text('الكل'),
                  selected: true,
                  showCheckmark: false,
                  labelStyle:
                      text.labelMedium!.copyWith(color: p.bg),
                  onSelected: (_) {}),
              ChoiceChip(
                  label: const Text('♥ المفضلة'),
                  selected: false,
                  onSelected: (_) {}),
              ChoiceChip(
                  label: const Text('فيديو'),
                  selected: false,
                  onSelected: (_) {}),
              ChoiceChip(
                  label: const Text('صوت'),
                  selected: false,
                  onSelected: (_) {}),
            ],
          ),
          const SizedBox(height: MTSpace.xl),

          const MTSectionHeader(title: 'تحميل جارٍ', trailing: 'بطاقة حية'),
          const SizedBox(height: MTSpace.md),
          MTDownloadProgressCard(
            title: 'أنشودة الفجر — نسخة المسجد الكبير',
            statusText: 'يسحب من السيرفر · 64٪',
            progress: 0.64,
            onCancel: () {},
          ),
          const SizedBox(height: MTSpace.xs),
          MTDownloadProgressCard(
            title: 'مقطع محظور المنصة',
            statusText: 'المنصة تطلب تسجيل الدخول — حدّث الكوكيز',
            isError: true,
            onCancel: () {},
          ),
          const SizedBox(height: MTSpace.xl),

          const MTSectionHeader(title: 'بطاقات الوسائط', trailing: '٥ حالات'),
          MTMediaCard(
            title: 'خطبة الجمعة — أهمية الوقت في حياة المسلم',
            duration: '42:18',
            platform: MTPlatformKind.youtube,
            subtitle: 'قناة المنبر · قبل ٣ أيام',
            location: MTMediaLocation.offline,
            locationLabel: 'دون اتصال',
            favorite: true,
            onFavoriteToggle: () {},
            onMore: () {},
            onTap: () {},
          ),
          MTMediaCard(
            title: 'أنشودة يا طيبة — مؤثرات',
            duration: '04:05',
            platform: MTPlatformKind.soundcloud,
            subtitle: 'أناشيد الفجر',
            location: MTMediaLocation.onServer,
            locationLabel: 'على السيرفر',
            playing: true,
            onTap: () {},
          ),
          MTMediaCard(
            title: 'عنصر محدد (وضع التحديد المتعدد)',
            platform: MTPlatformKind.tiktok,
            subtitle: '2.1MB · أمس',
            selected: true,
            onTap: () {},
          ),
          MTMediaCard(
            title: 'بطاقة مضغوطة بسطر واحد فقط للعرض الكثيف',
            duration: '1:03',
            platform: MTPlatformKind.instagram,
            subtitle: '12MB',
            compact: true,
            onMore: () {},
            onTap: () {},
          ),
          const SizedBox(height: MTSpace.xl),

          const MTSectionHeader(title: 'أزرار وتنبيهات'),
          const SizedBox(height: MTSpace.md),
          Row(
            children: [
              FilledButton(onPressed: () {}, child: const Text('فعل أساسي')),
              const SizedBox(width: MTSpace.sm),
              OutlinedButton(onPressed: () {}, child: const Text('ثانوي')),
            ],
          ),
          const SizedBox(height: MTSpace.md),
          Wrap(
            spacing: MTSpace.xs,
            children: [
              ActionChip(
                  label: const Text('نجاح'),
                  onPressed: () => showMTSnack(context, 'تم الحفظ بنجاح',
                      type: MTSnackType.success)),
              ActionChip(
                  label: const Text('خطأ'),
                  onPressed: () => showMTSnack(context, 'تعذر الوصول للسيرفر',
                      type: MTSnackType.error)),
              ActionChip(
                  label: const Text('تراجع'),
                  onPressed: () => showMTSnack(context, 'حُذف العنصر',
                      actionLabel: 'تراجع', onAction: () {})),
            ],
          ),
          const SizedBox(height: MTSpace.xl),

          const MTSectionHeader(title: 'حالة فارغة'),
          MTEmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'لا سيرفر بعد',
            message: 'أدخل رابط سيرفر MeTube من الإعدادات لبدء التحميل',
            actionLabel: 'فتح الإعدادات',
            onAction: () {},
          ),
        ],
      ),
    );
  }

  void _openUrlSheet(BuildContext context) {
    final controller = TextEditingController(
        text: 'https://youtu.be/dQw4w9WgXcQ');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => MTUrlInputSheet(
        title: 'إضافة رابط',
        urlHint: 'الصق الرابط هنا…',
        controller: controller,
        platform: MTPlatformKind.youtube,
        platformLabel: 'YouTube',
        qualities: const [
          MTQualityOption(value: 'best', label: 'الأفضل'),
          MTQualityOption(value: '1080', label: '1080p'),
          MTQualityOption(value: '720', label: '720p'),
          MTQualityOption(value: '480', label: '480p'),
          MTQualityOption(value: 'audio', label: 'صوت فقط'),
        ],
        selectedQuality: 'best',
        onQualitySelected: (_) {},
        startLabel: 'ابدأ التحميل',
        onStart: () => Navigator.pop(sheetContext),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.label, this.color, {this.ink});

  final String label;
  final Color color;
  final Color? ink;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final on = ink ?? (color.computeLuminance() > 0.5 ? p.ink : p.bg);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: MTSpace.md, vertical: MTSpace.xs),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(MTRadius.chip),
        border: Border.all(color: p.line),
      ),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .labelMedium!
              .copyWith(color: on)),
    );
  }
}
