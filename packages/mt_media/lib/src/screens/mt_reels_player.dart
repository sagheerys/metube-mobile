import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/playback_source.dart';
import '../models/playlist_item.dart';
import '../video/reels_overlay.dart';
import '../video/reels_progress.dart';
import '../video/reels_stage.dart';
import '../video/shorts_lane.dart';
import 'mt_video_screen.dart';

part 'mt_reels_player_controls.dart';

/// **مشغل الريلز (م-35)** — غامر بسحب عمودي داخل «مسار القِصار» فقط:
/// القِصار العمودية من القائمة المعروضة بنفس ترتيبها، والصوتي والعرضي
/// يُتخطيان بصمت (العداد يعدّ القِصار وحدها).
///
/// المقطع **يتكرر** حتى السحب، ولا يُحفظ له موضع استئناف (قاعدة م-35).
/// نقرة = إيقاف/تشغيل · مزدوجة = مفضلة · عمود أفعال جانبي.
class MTReelsPlayer extends StatefulWidget {
  const MTReelsPlayer({
    super.key,
    required this.lane,
    required this.resolver,
    this.startIndex = 0,
    this.isFavorite,
    this.onToggleFavorite,
    this.onDoubleTapFavorite,
    this.actionsBuilder,
    this.subtitleBuilder,
    this.onContinueRest,
    this.onTakeAudioFocus,
    this.onLive,
  });

  final ShortsLane lane;
  final PlaybackSourceResolver resolver;
  final int startIndex;
  final bool Function(PlaylistItem item)? isFavorite;

  /// **زر القلب في العمود الجانبي** — `null` ⇒ لا يُعرض أصلاً. طلب
  /// المالك 2026-09-04: زر «أضف إلى…» يغني عنه.
  final void Function(PlaylistItem item)? onToggleFavorite;

  /// **الضغطة المزدوجة (م-36)** — تبقى اختصار المفضلة ولو غاب القلب من
  /// العمود. حين لا تُمرَّر يُستعمل [onToggleFavorite] كما كان.
  final void Function(PlaylistItem item)? onDoubleTapFavorite;
  final List<MTPlayerAction> Function(PlaylistItem item)? actionsBuilder;
  final String Function(BuildContext context, PlaylistItem item)?
      subtitleBuilder;

  /// «متابعة بقية القائمة» — يفتح أول عنصر غير قصير في مشغله الصحيح.
  final VoidCallback? onContinueRest;

  /// يوقف مشغل الصوت الخلفي قبل أول تشغيل — وإلا اشتغل الصوت والريل معاً.
  final Future<void> Function()? onTakeAudioFocus;

  /// **الاتجاه المعاكس للقاعدة الذهبية (العطل ع-4).** يُسلَّم للأعلى
  /// «موقفَ هذا المشغل» عند الحياة و`null` عند الموت، فيستطيع مشغل الصوت
  /// إسكات الريل قبل أن يعزف. بلا هذا كانت ضغطة تشغيل واحدة في إشعار
  /// الوسائط تُسمع **مصدرين معاً**.
  final void Function(Future<void> Function()? pauser)? onLive;

  @override
  State<MTReelsPlayer> createState() => _MTReelsPlayerState();
}

class _MTReelsPlayerState extends State<MTReelsPlayer> {
  late final PageController _pages =
      PageController(initialPage: widget.startIndex);
  VideoPlayerController? _controller;
  late int _index = widget.startIndex;
  bool _endReached = false;
  bool _failed = false;

  /// **حارس السباق (خلل مصطاد على جهاز المالك 2026-09-01).** السحب أسرع
  /// من `initialize()` — سحبتان متتاليتان تبدآن تحميلين متوازيين، ويفوز
  /// آخر من ينتهي بـ `_controller` بينما **يبقى الأول حياً يشتغل صوتاً
  /// خلف الصورة الجديدة**. كل سحبة إضافية تضيف صوتاً ثالثاً ورابعاً.
  int _generation = 0;

  /// **الأدوات تختفي بعد لحظة** (طلب المالك 2026-09-02). القاعدة واحدة
  /// بلا أوضاع خفية: أي لمسة تُظهر الأدوات **وتقلب التشغيل** (م-35)، ثم
  /// تختفي بعد [_chromeLinger] إن بقي المقطع يعمل. الإيقاف يثبّتها —
  /// المتوقف يريد أن يقرأ ويتصرف، لا أن يشاهد.
  static const _chromeLinger = Duration(seconds: 3);
  bool _chrome = true;
  Timer? _hideTimer;

  /// **الشاشة كانت تطفأ أثناء المشاهدة** (بلاغ المالك 2026-09-02):
  /// `MTVideoSession` تمسك القفل لكن الريلز يملك متحكمه الخام مباشرة،
  /// فلم يكن أحد يمسكه هنا إطلاقاً.
  bool _wakelockOn = false;

  /// **علم الموت — ولا يُستبدل بـ`mounted` أبداً** (العطل الميداني
  /// 2026-09-03، مثبت بأثر على الجهاز).
  ///
  /// `State.mounted` هو `_element != null`، والإطار يصفّر `_element`
  /// **بعد** عودة `dispose()`. فإن رمى أي سطر داخل `dispose()` — وقد
  /// رمى: `onLive` أدناه — لم يُصفَّر، **فبقي `mounted == true` إلى
  /// الأبد على شاشة ميتة**. حينها يمرّ التحميل المعلّق من كل حُرّاس
  /// `mounted`، فيشغّل مقطعاً ويسلّمه لحقلٍ لن يصرّفه أحد: صوت يعمل
  /// خلف التطبيق بلا مشغل مصغر ولا سبيل لإيقافه (بلاغ المالك).
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    // **شريط الحالة يبقى مرئياً (بلاغ المالك 2026-09-02):** إنستقرام
    // وتيك توك يمدّان الفيديو خلف الشريط ولا يخفيانه — الساعة والبطارية
    // حق المستخدم، و`immersiveSticky` كان يبتلعهما ويجعل السحب من الحافة
    // يستدعي الشريط بدل تغيير المقطع.
    //
    // لون أيقوناته يُضبط بـ `AnnotatedRegion` في `build` لا هنا — انظر
    // التعليق هناك، فالسبب مثبت بـ `dumpsys` لا مستنتج.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _notifyLive(_pauseForAudioFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(_index));
  }

  /// `setState` محمية ولا تُنادى من امتداد ولو في نفس المكتبة — هذه
  /// نافذتها الوحيدة لملف الأوامر (`part`)، نفس نمط
  /// `MTVideoSession.notifyFromCommands`.
  void applyState(VoidCallback fn) => setState(fn);

  /// **رد نداء المضيف محصَّن**: `onLive` يصل غالباً إلى `ref` في تطبيق
  /// المضيف، و`ref.read` من `ConsumerState` بعد إبطاله **يرمي**. رميةٌ
  /// واحدة داخل `dispose()` كانت تُسقط كل ما بعدها (انظر [_disposed]).
  void _notifyLive(Future<void> Function()? pauser) {
    try {
      widget.onLive?.call(pauser);
    } on Object catch (error) {
      debugPrint('MTReelsPlayer: onLive threw — $error');
    }
  }

  /// **الترتيب هنا عقد لا تنسيق:** العلم أولاً ثم إبطال الأجيال ثم
  /// تحرير الموارد — وكل ما قد يرمي في النهاية ومحاطاً بحصانة.
  @override
  void dispose() {
    _disposed = true;
    _generation++; // تحميل معلّق لا يشغّل شيئاً بعد هذه اللحظة
    _hideTimer?.cancel();
    final controller = _controller;
    _controller = null;
    if (controller != null) unawaited(_shutdownController(controller));
    unawaited(_setWakelock(false));
    _pages.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // إعادة أيقونات النظام لما يقرره الثيم — الريلز وحده داكن دائماً.
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _notifyLive(null);
    super.dispose();
  }

  PlaylistItem? get _current =>
      _index >= 0 && _index < widget.lane.length ? widget.lane.items[_index] : null;

  void _onPageChanged(int page) {
    if (_disposed) return;
    if (page >= widget.lane.length) {
      setState(() {
        _endReached = true;
        _chrome = true;
      });
      _hideTimer?.cancel();
      _controller?.pause();
      unawaited(_setWakelock(false));
      return;
    }
    setState(() {
      _index = page;
      _endReached = false;
    });
    _load(page);
  }

  /// **السحب على الشريط يمرّ بمالك الحالة (العطل ط-3).** كان الشريط
  /// ينادي `controller.play()` مباشرة — الاستدعاء الوحيد في الحزمة بلا
  /// تركيز صوت ولا محاسبة قفل شاشة: تستأنف بعد سحبة فتنام الشاشة أثناء
  /// التشغيل (بلاغك نفسه من باب خلفي)، ويعود الصوت الخلفي فيُسمع اثنان.
  bool _resumeAfterScrub = false;

  @override
  Widget build(BuildContext context) {
    final item = _current;
    // **الشريط كان ظاهراً وغير مقروء** (بلاغ المالك «يغطي الشريط
    // العلوي»، وتشخيصه بـ `dumpsys window` 2026-09-02):
    // `vsysui=… LIGHT_STATUS_BAR` — أي أن النظام كان يرسم أيقوناته
    // **سوداء** لأن الثيم النهاري كريمي، فوق خلفية الريلز السوداء.
    // النتيجة شريط موجود لا يُرى منه شيء: الساعة والبطارية سواد على
    // سواد (قياس البكسل: القمة كلها 0,0,0).
    //
    // و`SystemChrome.setSystemUIOverlayStyle` في `initState` لا يكفي:
    // الإطار يعيد فرض نمط الطبقات كل إطار من `AnnotatedRegion` الأعلى
    // في الشجرة، فتُداس القيمة المضبوطة مرة واحدة. `AnnotatedRegion`
    // هنا يشارك في القرار كل إطار ويفوز لأنه الأعلى.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pages,
            scrollDirection: Axis.vertical,
            // صفحة زائدة واحدة = بطاقة «انتهت القِصار» بعد ارتداد السحب.
            itemCount: widget.lane.length + 1,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, page) => page >= widget.lane.length
                ? const SizedBox.expand()
                : ReelsVideoLayer(
                    controller: page == _index ? _controller : null,
                    failed: page == _index && _failed,
                    onTap: _togglePlay,
                    onDoubleTap: () {
                      final target = widget.lane.items[page];
                      // م-36: الضغطة المزدوجة إيماءة عمياء — النبضة هي
                      // التأكيد الوحيد أن التبديل وقع فعلاً.
                      HapticFeedback.selectionClick();
                      (widget.onDoubleTapFavorite ?? widget.onToggleFavorite)
                          ?.call(target);
                      setState(() {});
                    },
                  ),
          ),
          if (_endReached)
            MTReelsEndCard(
              onBack: () => Navigator.of(context).maybePop(),
              onContinueRest: widget.onContinueRest,
              onReplay: () {
                _pages.jumpToPage(0);
                _onPageChanged(0);
              },
            )
          else if (item != null) ...[
            ReelsOverlayLayer(
              item: item,
              index: _index,
              total: widget.lane.length,
              favorite: widget.isFavorite?.call(item) ?? false,
              onToggleFavorite: widget.onToggleFavorite == null
                  ? null
                  : () {
                      widget.onToggleFavorite!(item);
                      setState(() {});
                      _showChrome();
                    },
              actions: widget.actionsBuilder?.call(item) ?? const [],
              subtitle: widget.subtitleBuilder?.call(context, item),
              visible: _chrome,
            ),
            // **الشريط وحده يبقى دائماً** (طلب المالك): هو المرجع الوحيد
            // لموضعك في المقطع، وإخفاؤه مع الأدوات يجعل التقديم مستحيلاً
            // إلا بلمستين. لذلك هو **خارج** طبقة الأدوات المتلاشية.
            PositionedDirectional(
              start: MTSpace.lg,
              end: MTSpace.lg,
              bottom: MTSpace.sm,
              child: SafeArea(
                top: false,
                child: ReelsProgressBar(
                  controller: _controller,
                  onScrubStart: _onScrubStart,
                  onScrubEnd: () => unawaited(_onScrubEnd()),
                ),
              ),
            ),
          ],
          ],
        ),
      ),
    );
  }
}
