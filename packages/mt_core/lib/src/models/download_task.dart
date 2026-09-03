import 'package:uuid/uuid.dart';

import '../api/api_exceptions.dart';
import 'quality.dart';

const _uuid = Uuid();

/// مراحل مهمة التحميل عبر الخط الرباعي (`05-DATA-SCHEMA.md` §3):
/// add ← poll ← pull ← delete(حسب السياسة).
enum TaskPhase {
  queued,
  adding,
  polling,

  /// الملف جاهز على السيرفر و**السحب موقوف بانتظار Wi‑Fi** (م-42).
  ///
  /// مرحلة مستقلة عن `pulling` بقصد: التقدم لا يتحرك هنا، والسبب ليس
  /// بطء شبكة بل قرار المستخدم — عرضها كـ«يسحب 0٪» كذب يجعله يظن
  /// التطبيق معلقاً، وعرضها كـ«فشل» كذب آخر.
  waitingForNetwork,
  pulling,
  deleting,
  completed,
  failed,
  cancelled,
}

/// مهمة تحميل واحدة — معرفها uuid v4 (لا `url.hashCode` الهش القديم).
/// كائن غير قابل للتغيير؛ محرك التحميل (المرحلة 2) يتقدم بها عبر [copyWith].
class DownloadTask {
  DownloadTask({
    String? id,
    required this.inputUrl,
    required this.quality,
    this.resolvedUrl,
    this.canonicalUrl,
    this.serverFilename,
    this.title,
    this.thumbnail,
    this.localPath,
    this.phase = TaskPhase.queued,
    this.progress = 0,
    this.error,
    this.isBatchMember = false,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  final String id;

  /// كما أدخله المستخدم (للعرض وإعادة المحاولة).
  final String inputUrl;

  /// بعد حل الرابط القصير — هو ما يُرسل إلى `/add`.
  final String? resolvedUrl;

  /// من `/history` — **الوحيد** الصالح للحذف والفهرسة.
  final String? canonicalUrl;
  final String? serverFilename;

  /// عنوان السيرفر وغلافه لحظة الاكتمال — يُستعملان لاسم الملف المحلي
  /// (§2.4) وفهرسي العنوان والغلاف وإشعار الاكتمال (م-9). **لا يُختلقان**
  /// إن غابا (فخ §6.3).
  final String? title;
  final String? thumbnail;
  final String? localPath;
  final Quality quality;
  final TaskPhase phase;

  /// 0..1: تقدم السيرفر أثناء polling ثم تقدم السحب أثناء pulling.
  final double progress;

  /// الخطأ المصنف عند الفشل — التطبيق يحوّل نوعه لنص مترجم (TRD §3.3).
  final MTApiException? error;

  /// المفرد يتقدم على أعضاء الدفعات في الطابور.
  final bool isBatchMember;
  final DateTime createdAt;

  /// **هل لهذه المرحلة تقدم معروف؟** المنتظِرة وموقوفة الشبكة لا تتحرك،
  /// فعرض «0٪» عليها كذب يوحي بالتعليق (نفس منطق `waitingForNetwork`).
  bool get hasKnownProgress =>
      phase != TaskPhase.queued && phase != TaskPhase.waitingForNetwork;

  bool get isFinished =>
      phase == TaskPhase.completed ||
      phase == TaskPhase.failed ||
      phase == TaskPhase.cancelled;

  String get effectiveUrl => resolvedUrl ?? inputUrl;

  DownloadTask copyWith({
    String? resolvedUrl,
    String? canonicalUrl,
    String? serverFilename,
    String? title,
    String? thumbnail,
    String? localPath,
    TaskPhase? phase,
    double? progress,
    MTApiException? error,
  }) =>
      DownloadTask(
        id: id,
        inputUrl: inputUrl,
        quality: quality,
        resolvedUrl: resolvedUrl ?? this.resolvedUrl,
        canonicalUrl: canonicalUrl ?? this.canonicalUrl,
        serverFilename: serverFilename ?? this.serverFilename,
        title: title ?? this.title,
        thumbnail: thumbnail ?? this.thumbnail,
        localPath: localPath ?? this.localPath,
        phase: phase ?? this.phase,
        progress: progress ?? this.progress,
        error: error ?? this.error,
        isBatchMember: isBatchMember,
        createdAt: createdAt,
      );
}

/// متوسط تقدم مجموعة مهام (0..1) — للشريط المُجمِّع أعلى المكتبة حين
/// تتعدد التحميلات (بلاغ المالك 2026-09-03).
///
/// المهام بلا تقدم معروف تُحسب **صفراً لا تُستبعد**: استبعادها يجعل
/// «٣ تحميلات» تعرض ٩٠٪ لأن واحدة فقط تعمل والباقي في الطابور.
/// المجموعة الفارغة أو التي لا تقدم فيها بتاتاً ⇒ `null` (شريط غير محدد).
double? averageTaskProgress(List<DownloadTask> tasks) {
  if (tasks.isEmpty) return null;
  if (!tasks.any((t) => t.hasKnownProgress)) return null;
  var sum = 0.0;
  for (final task in tasks) {
    if (task.hasKnownProgress) sum += task.progress.clamp(0, 1);
  }
  return sum / tasks.length;
}
