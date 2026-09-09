# -*- coding: utf-8 -*-
"""توليد أيقونات المشغّل — «الشريط» (قرار المالك 2026-09-09).

الفكرة: إطار فيلم بثقوبه، ولوحة كريمية في وسطه **الرمز مقتطع منها**
فيظهر لون الفعل من خلفه — سوبر مثلث تشغيل، لايت سهم هابط.

ثلاث طبقات لكل تطبيق في `assets/icons/`:
  icon.png             — الأيقونة القديمة كاملةً (مقصوصة بشكل سوبر-إهليلج
                         لأن أندرويد ما قبل 8 يعرضها كما هي بلا قناع).
  icon_foreground.png  — الطبقة الأمامية: التصميم كله عند 92٪ من الملف
                         (راجع [FIT] — الأداة تضيف inset 16٪ فوقها).
  icon_monochrome.png  — أندرويد 13+ «الأيقونات المتناسقة»: صورة ظليّة
                         بيضاء يلوّنها النظام. كانت غائبة تماماً فكانت
                         الأيقونة تظهر شاذّة عند تفعيل الخيار.
الخلفية لونٌ صلب في pubspec لا صورة — فالتصميم لا يحتاج تفصيلاً خلفها.

**تدوير الزوايا بفتحٍ مورفولوجي** (طمس ثم عتبة): تقليص المضلّع نحو مركزه
يشوّه المثلثات غير المتساوية الأضلاع — نُتوءٌ في زاوية وقصٌّ في أخرى.

التشغيل: python tool/make_icons.py   ثم  dart run flutter_launcher_icons
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

DESIGN = 512          # وحدات التصميم
OUT = 1024            # مقاس الإخراج
SS = 3                # الإفراط في العيّنات
N = OUT * SS
# **حسابان لا واحد**: `flutter_launcher_icons` يلفّ الطبقة الأمامية بـ
# `inset 16%` بنفسه، فتصير 68٪ من اللوحة (≈73dp من 108) — أي أنها تغطي
# المنطقة المرئية (72dp) تماماً. لكن القناع **دائري** في بعض المشغّلات،
# وأبعد نقطة في التصميم هي زاوية الثقب العلوي: نصف قطرها 0.5245 من عرض
# الرسم، فلا تدخل الدائرة إلا إذا صغّرناه إلى 92٪ داخل الملف. بلا هذا
# تُقصّ أطراف الثقوب فتبدو كأنها عطل.
FIT = 0.92

CREAM = (251, 246, 238, 255)
APPS = {
    'metube_lite': {'accent': (47, 109, 116, 255), 'glyph': 'download'},
    'metube_super': {'accent': (194, 94, 46, 255), 'glyph': 'play'},
}

PERF_X = (36, 434)
PERF_Y = (102, 223, 344)
PERF = (42, 66, 15)                      # عرض · ارتفاع · تدوير
PANEL = (104, 88, 408, 424, 46)


def u(v):
    return int(round(v * (OUT / DESIGN) * SS))


def rrect(d, box, r, fill):
    d.rounded_rectangle([u(box[0]), u(box[1]), u(box[2]), u(box[3])],
                        radius=u(r), fill=fill)


def round_corners(mask, radius):
    m = mask.filter(ImageFilter.GaussianBlur(u(radius) * 0.62))
    return m.point(lambda v: 255 if v >= 128 else 0)


def squircle(size, n=4.2):
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    c = (size - 1) / 2
    v = (np.abs(x - c) / c) ** n + (np.abs(y - c) / c) ** n
    return Image.fromarray(
        (np.clip((1 - v) * size * 0.35, 0, 1) * 255).astype(np.uint8), 'L')


def glyph_mask(kind):
    m = Image.new('L', (N, N), 0)
    d = ImageDraw.Draw(m)
    if kind == 'play':
        # مربّع الإحاطة مركزه 264 لا 256: كتلة المثلث يسار رأسه، فالتوسيط
        # الحسابي يجعله يبدو مزاحاً لليسار (توسيط بصري).
        d.polygon([(u(184), u(150)), (u(184), u(362)), (u(344), u(256))],
                  fill=255)
    else:
        rrect(d, (228, 118, 284, 262), 28, 255)
        d.polygon([(u(166), u(244)), (u(346), u(244)), (u(256), u(382))],
                  fill=255)
    return round_corners(m, 13)


def artwork_mask(kind):
    """الثقوب + اللوحة، ناقصاً الرمز — الصورة الظليّة للتصميم كله."""
    m = Image.new('L', (N, N), 0)
    d = ImageDraw.Draw(m)
    for x in PERF_X:
        for y in PERF_Y:
            rrect(d, (x, y, x + PERF[0], y + PERF[1]), PERF[2], 255)
    rrect(d, PANEL[:4], PANEL[4], 255)
    return Image.fromarray(
        np.minimum(np.array(m), 255 - np.array(glyph_mask(kind))), 'L')


def tinted(mask, color):
    img = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    img.paste(Image.new('RGBA', (N, N), color), (0, 0), mask)
    return img.resize((OUT, OUT), Image.LANCZOS)


def into_safe_zone(layer):
    """التصميم داخل الدائرة المضمونة (راجع [FIT])."""
    side = int(round(OUT * FIT))
    out = Image.new('RGBA', (OUT, OUT), (0, 0, 0, 0))
    out.paste(layer.resize((side, side), Image.LANCZOS),
              ((OUT - side) // 2, (OUT - side) // 2))
    return out


def main():
    for app, cfg in APPS.items():
        mask = artwork_mask(cfg['glyph'])
        art = tinted(mask, CREAM)

        full = Image.new('RGBA', (OUT, OUT), cfg['accent'])
        full.alpha_composite(art)
        full.putalpha(squircle(OUT))
        base = f'apps/{app}/assets/icons'
        full.save(f'{base}/icon.png')
        into_safe_zone(art).save(f'{base}/icon_foreground.png')
        into_safe_zone(tinted(mask, (255, 255, 255, 255))).save(
            f'{base}/icon_monochrome.png')
        print(f'{app}: icon.png · icon_foreground.png · icon_monochrome.png')


if __name__ == '__main__':
    main()
