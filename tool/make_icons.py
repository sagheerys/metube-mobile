# توليد أيقونات المشغّل من الهوية المعتمدة (سجل §4 في
# `docs/plan/04-UIUX-DESIGN-BRIEF.md`): «أيقونتان توأمان — Super مثلث
# تشغيل وهج / Lite سهم تحميل بترولي — بشارة اسم سفلية».
#
# المخرجات في `assets/icons/` لكل تطبيق:
#   icon.png            — الأيقونة القديمة الكاملة (بالشارة السفلية)
#   icon_foreground.png — طبقة adaptive: الرمز وحده داخل المنطقة الآمنة
#                         (66% من 108dp) وإلا قصّه القناع الدائري.
#
# التشغيل: python tool/make_icons.py   ثم  dart run flutter_launcher_icons
from PIL import Image, ImageDraw, ImageFont

SIZE = 1024
CREAM = (251, 246, 238, 255)
INK = (43, 33, 27, 255)

APPS = {
    'metube_lite': {
        'accent': (47, 109, 116, 255),   # خليج بترولي #2F6D74
        'soft': (223, 235, 234, 255),    # #DFEBEA
        'glyph': 'download',
        'badge': 'LITE',
    },
    'metube_super': {
        'accent': (194, 94, 46, 255),    # وهج #C25E2E
        'soft': (246, 228, 214, 255),    # #F6E4D6
        'glyph': 'play',
        'badge': 'SUPER',
    },
}

FONT = 'packages/mt_ui/assets/fonts/NotoKufiArabic-Bold.ttf'


def rounded(draw, box, radius, fill):
    draw.rounded_rectangle(box, radius=radius, fill=fill)


def draw_play(draw, cx, cy, r, color):
    """مثلث تشغيل بزوايا مدوّرة — الهوية «هادئة مطبوعة» لا حادة:
    يُرسم المضلع مقلَّصاً نحو مركزه ثم يُغلَّف بخط سميك بوصلات دائرية."""
    radius = r * 0.16
    raw = [
        (cx - r * 0.52, cy - r * 0.72),
        (cx + r * 0.78, cy),
        (cx - r * 0.52, cy + r * 0.72),
    ]
    gx = sum(p[0] for p in raw) / 3
    gy = sum(p[1] for p in raw) / 3
    points = []
    for x, y in raw:
        dx, dy = x - gx, y - gy
        length = (dx * dx + dy * dy) ** 0.5
        k = (length - radius) / length
        points.append((gx + dx * k, gy + dy * k))
    draw.polygon(points, fill=color)
    # تكرار النقطة الثانية يُغلق الحلقة فتكون **كل** الوصلات دائرية —
    # بدونه يبقى طرف الخط الأول مسطحاً فيظهر نتوء في الزاوية العليا.
    draw.line(points + [points[0], points[1]], fill=color,
              width=int(radius * 2), joint='curve')


def draw_download(draw, cx, cy, r, color):
    """سهم تحميل: عمود + رأس مثلث + خط قاعدة (نفس معنى «حمّل واحتفظ»)."""
    stem_w = r * 0.30
    draw.rounded_rectangle(
        [cx - stem_w / 2, cy - r * 0.86, cx + stem_w / 2, cy + r * 0.10],
        radius=stem_w / 2, fill=color)
    draw.polygon([
        (cx - r * 0.62, cy - r * 0.06),
        (cx + r * 0.62, cy - r * 0.06),
        (cx, cy + r * 0.62),
    ], fill=color)
    base_h = r * 0.20
    draw.rounded_rectangle(
        [cx - r * 0.78, cy + r * 0.80, cx + r * 0.78, cy + r * 0.80 + base_h],
        radius=base_h / 2, fill=color)


GLYPHS = {'play': draw_play, 'download': draw_download}


def build(app, spec):
    # ── الأيقونة الكاملة (قديمة/احتياطية): لوح ناعم + رمز + شارة اسم ──
    full = Image.new('RGBA', (SIZE, SIZE), CREAM)
    d = ImageDraw.Draw(full)
    pad = SIZE * 0.11
    rounded(d, [pad, pad, SIZE - pad, SIZE - pad], SIZE * 0.20, spec['soft'])
    GLYPHS[spec['glyph']](d, SIZE / 2, SIZE * 0.44, SIZE * 0.21,
                          spec['accent'])

    font = ImageFont.truetype(FONT, int(SIZE * 0.088))
    text = spec['badge']
    tw = d.textbbox((0, 0), text, font=font)
    w, h = tw[2] - tw[0], tw[3] - tw[1]
    bx, by = SIZE / 2, SIZE * 0.775
    px, py = SIZE * 0.055, SIZE * 0.032
    rounded(d, [bx - w / 2 - px, by - h / 2 - py,
                bx + w / 2 + px, by + h / 2 + py],
            (h + 2 * py) / 2, spec['accent'])
    d.text((bx - w / 2 - tw[0], by - h / 2 - tw[1]), text, font=font,
           fill=CREAM)

    # ── طبقة adaptive الأمامية: الرمز وحده، أصغر ليصمد أمام أي قناع ──
    # (الشارة تُترك للأيقونة القديمة: القناع الدائري يقصّ أسفل الأيقونة،
    #  والتمييز الحقيقي بين النسختين هو اللون والرمز على أي حال.)
    fg = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    fd = ImageDraw.Draw(fg)
    # نصف القطر 0.23 من الحافة: الدائرة المرئية في الأيقونة التكيفية
    # نصف قطرها 0.333، فيبقى هامش أمان مريح مع حضور بصري كافٍ.
    GLYPHS[spec['glyph']](fd, SIZE / 2, SIZE / 2, SIZE * 0.23,
                          spec['accent'])

    out = f'apps/{app}/assets/icons'
    import os
    os.makedirs(out, exist_ok=True)
    full.save(f'{out}/icon.png')
    fg.save(f'{out}/icon_foreground.png')
    print('wrote', out)


for app, spec in APPS.items():
    build(app, spec)
