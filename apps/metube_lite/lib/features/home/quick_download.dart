import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import 'add_flow.dart';

/// اسم الجودة كما يراها المستخدم — تُعرض **المطبَّقة فعلاً** لا المختارة.
String qualityLabel(MTLocalizations l10n, Quality quality) =>
    switch (quality) {
      Quality.best => l10n.qualityBest,
      Quality.q1080 => l10n.quality1080,
      Quality.q720 => l10n.quality720,
      Quality.q480 => l10n.quality480,
      Quality.audio => l10n.audioOnly,
    };

/// **التحميل السريع**: الرابط ينزل فوراً بالجودة الافتراضية بلا ورقة.
///
/// ثلاثة قرارات مقصودة:
/// 1. **القوائم لا تُحمَّل بصمت أبداً** مهما كان الإعداد — رابط قائمة
///    يفتح شاشة الدفعي ليقرر المستخدم؛ ٢٠٠ مقطع لا تبدأ بضغطة عمياء.
/// 2. **الجودة المعروضة هي المطبَّقة**: `Quality.applyRule` يُجبر الرقمية
///    على `best` خارج يوتيوب (قيد yt-dlp)، فعرض «1080» لرابط تيك توك
///    كذب على المستخدم. نعرض ما ذهب للخادم حرفياً.
/// 3. **تراجع لا تأكيد**: حوار تأكيد يُبطل معنى «سريع»؛ بدلاً منه فعل في
///    الشريط يلغي المهمة ويفتح الورقة بنفس الرابط.
///
/// **بوابة الإعداد هنا لا عند المنادي** (بلاغ المالك 2026-09-04:
/// «التحميل السريع مفعّل على طول رغم إيقافه»). كان الشرط مكتوباً في
/// مسار المشاركة وحده، بينما زر الإضافة العائم واختصار الأيقونة
/// ينزّلان فوراً بلا سؤال — فبدا الإعداد بلا أثر. البوابة داخل الدالة
/// تجعل نسيانها مستحيلاً.
///
/// [explicit] لفعل صريح لا لبس فيه (زر «حمّل الآن» في شريط الحافظة،
/// وبجانبه «اختر الخيارات») — هذا يعمل مهما كان الإعداد.
///
/// يرجع `false` إن لم يستطع التنفيذ (الإعداد مطفأ، قائمة، لا خادم)
/// فيتولى المنادي الورقة.
bool startQuickDownload(
  BuildContext context,
  WidgetRef ref,
  String url, {
  bool announce = true,
  bool explicit = false,
}) {
  if (PlaylistDetector.isPlaylist(url)) return false;
  if (!explicit && !ref.read(settingsProvider).quickDownload) return false;
  final engine = ref.read(downloadEngineProvider);
  if (engine == null) return false;

  final l10n = context.mtl;
  final messenger = ScaffoldMessenger.of(context);
  final chosen = ref.read(settingsProvider).quality;
  final effective = chosen.applyRule(url);
  final task = engine.submit(url, chosen);
  if (!announce) return true;

  showMTSnackOn(
    messenger,
    l10n.downloadStartedQuality(qualityLabel(l10n, effective)),
    type: MTSnackType.success,
    themeContext: context,
    actionLabel: l10n.changeQuality,
    onAction: () {
      engine.cancel(task.id);
      if (context.mounted) openAddSheet(context, ref, initialUrl: url);
    },
  );
  return true;
}
