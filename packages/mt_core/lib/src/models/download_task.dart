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

  bool get isFinished =>
      phase == TaskPhase.completed ||
      phase == TaskPhase.failed ||
      phase == TaskPhase.cancelled;

  String get effectiveUrl => resolvedUrl ?? inputUrl;

  DownloadTask copyWith({
    String? resolvedUrl,
    String? canonicalUrl,
    String? serverFilename,
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
        localPath: localPath ?? this.localPath,
        phase: phase ?? this.phase,
        progress: progress ?? this.progress,
        error: error ?? this.error,
        isBatchMember: isBatchMember,
        createdAt: createdAt,
      );
}
