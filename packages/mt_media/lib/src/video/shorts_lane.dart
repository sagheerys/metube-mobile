import '../models/playlist_item.dart';

/// **مسار القِصار المصفّى (م-35)** — منطق خالص قابل للاختبار.
///
/// قاعدة صارمة: السحب يتنقل بين القِصار العمودية من القائمة المعروضة
/// **بنفس ترتيبها**؛ الصوتي والعرضي يُتخطيان بصمت، والعداد يعدّ القِصار
/// وحدها. المجهول (بلا مدة أو نسبة) ليس قصيراً — لا تخمين.
class ShortsLane {
  const ShortsLane._(this.items, this.sourceIndices);

  /// القِصار فقط بترتيب القائمة الأصلية.
  final List<PlaylistItem> items;

  /// فهرس كل عنصر داخل القائمة الأصلية — للعودة لبقية القائمة.
  final List<int> sourceIndices;

  bool get isEmpty => items.isEmpty;
  int get length => items.length;

  /// يبني المسار من القائمة المعروضة.
  factory ShortsLane.from(List<PlaylistItem> source) {
    final items = <PlaylistItem>[];
    final indices = <int>[];
    for (var i = 0; i < source.length; i++) {
      if (source[i].isShortForm) {
        items.add(source[i]);
        indices.add(i);
      }
    }
    return ShortsLane._(items, indices);
  }

  /// موضع عنصر داخل المسار (-1 إن لم يكن قصيراً).
  int laneIndexOf(String canonicalUrl) =>
      items.indexWhere((i) => i.canonicalUrl == canonicalUrl);

  /// أول عنصر **غير قصير** بعد نهاية المسار — زر «متابعة بقية القائمة»
  /// يفتحه في مشغله الصحيح. null إن لم يبق شيء.
  int? nextNonShortIndex(List<PlaylistItem> source) {
    final last = sourceIndices.isEmpty ? -1 : sourceIndices.last;
    for (var i = last + 1; i < source.length; i++) {
      if (!source[i].isShortForm) return i;
    }
    for (var i = 0; i < source.length; i++) {
      if (!source[i].isShortForm) return i;
    }
    return null;
  }
}
