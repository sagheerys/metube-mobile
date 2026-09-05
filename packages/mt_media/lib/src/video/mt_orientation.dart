import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// **سياسة الاتجاه (قرار المالك 2026-09-05): التطبيق طولي، والمشغل وحده
/// يدور** — وهو سلوك يوتيوب نفسه على الهاتف.
///
/// السبب ليس كسلاً: المكتبة عرضياً على هاتف تعطي سطرين ونصف وشريطاً
/// علوياً يأكل ثلث الارتفاع. أما الفيديو فالعرضي شكله الطبيعي.
/// (اللوحي مسألة **عرض** لا اتجاه — دفعة مستقلة، وحينها يُرفع هذا
/// القفل عن الشاشات الكبيرة.)
abstract final class MTOrientation {
  /// `portraitDown` مستثنى عمداً: لا أحد يمسك هاتفه مقلوباً.
  static const portrait = <DeviceOrientation>[DeviceOrientation.portraitUp];
  static const landscape = <DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];
  static const free = <DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  static Future<void> lockPortrait() =>
      SystemChrome.setPreferredOrientations(portrait);
  static Future<void> lockLandscape() =>
      SystemChrome.setPreferredOrientations(landscape);
  static Future<void> allow() =>
      SystemChrome.setPreferredOrientations(free);
}

/// **نطاق التدوير حول المشغل العمودي**: يفكّ قفل الطولي ما دام المشغل
/// مفتوحاً، ويفتح الملء التام حين تُمال الجهاز، ويعيد القفل عند
/// المغادرة.
///
/// كان `setPreferredOrientations([portraitUp])` في `dispose` الملء
/// التام **يثبّت التطبيق كله على الطولي إلى أن يُقتل** (بلاغ المالك
/// 2026-09-05: «وضع العرض لا يعمل ولم يُطبَّق») — الأمر عام على
/// التطبيق ولا ينتهي بإغلاق الشاشة التي نادته.
class MTRotationScope extends StatefulWidget {
  const MTRotationScope({
    super.key,
    required this.open,
    required this.builder,
  });

  /// يفتح صفحة الملء التام ويكتمل عند إغلاقها. `byRotation` تخبر
  /// الصفحة كيف دخلت: بالإمالة (فتخرج بالإمالة العكسية) أم بالزر
  /// (فتفرض العرضي لأن المستخدم قد يكون قافلاً التدوير أصلاً).
  final Future<void> Function(bool byRotation) open;

  final Widget Function(BuildContext context, VoidCallback openFullscreen)
      builder;

  @override
  State<MTRotationScope> createState() => _MTRotationScopeState();
}

class _MTRotationScopeState extends State<MTRotationScope> {
  bool _open = false;

  /// **مسلَّح = مستعد للفتح بالإمالة.** يُنزع التسليح عند كل فتح ولا
  /// يعود إلا برؤية الطولي: بدونه يخرج المستخدم من الملء التام بالزر
  /// والجهاز ما يزال عرضياً، فيراه هذا النطاق عرضياً ويعيد الفتح فوراً
  /// — حلقة لا يخرج منها.
  bool _armed = true;

  @override
  void initState() {
    super.initState();
    MTOrientation.allow();
  }

  @override
  void dispose() {
    MTOrientation.lockPortrait();
    super.dispose();
  }

  Future<void> _openFullscreen(bool byRotation) async {
    if (_open || !mounted) return;
    _open = true;
    _armed = false;
    try {
      await widget.open(byRotation);
    } finally {
      _open = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    if (!landscape) {
      _armed = true;
    } else if (_armed && !_open) {
      // لا يُدفع مسار من داخل `build`.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openFullscreen(true);
      });
    }
    return widget.builder(context, () => _openFullscreen(false));
  }
}
