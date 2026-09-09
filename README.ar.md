# MeTube Mobile

[English](README.md) · **العربية**

[![CI](https://github.com/sagheerys/metube-mobile/actions/workflows/ci.yml/badge.svg)](https://github.com/sagheerys/metube-mobile/actions/workflows/ci.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Android-3DDC84.svg)](#المتطلبات)
[![Flutter](https://img.shields.io/badge/Flutter-3.47.2-02569B.svg)](https://flutter.dev)

تطبيقا أندرويد لسيرفر [MeTube](https://github.com/alexta69/metube) ذاتي
الاستضافة، في مستودع واحد (Flutter monorepo).

> **غير رسمي.** المشروع لا يتبع MeTube ولا yt-dlp ولا يمثّلهما ولا يحمل
> تزكيةً منهما، وإنما هو عميل مستقل يتحدث إلى سيرفر MeTube عبر واجهته
> البرمجية. الاسم يُذكر لبيان ما يتصل به التطبيقان لا أكثر.

| | **MeTube Lite** | **MeTube Super** |
|---|---|---|
| لمن | أفراد العائلة الذين يريدون الملف وحسب | من يدير السيرفر |
| بعد اكتمال التحميل | يسحبه للجهاز ثم **يحذفه من السيرفر** | **يُبقيه على السيرفر** |
| المكتبة | مسح للمجلد المحلي | `/history` والفهرس المحلي موحَّدين في قائمة واحدة |
| التشغيل | ملفات محلية | بثّ من السيرفر **و**ملفات محلية |
| الحصري | تحميل على Wi‑Fi فقط، وتنظيف السيرفر | وسوم، وتحميل دفعي، و«إتاحة دون اتصال»، وتبديل عناوين السيرفر |

التطبيقان يتقاسمان حزم النواة والوسائط والتصميم نفسها، ويصدران
**بالعربية والإنجليزية** بتخطيط يبدأ من اليمين.

## لقطات

| MeTube Lite | MeTube Super |
|---|---|
| ![لايت، نهاراً](docs/screenshots/lite-day.png) | ![سوبر، نهاراً](docs/screenshots/super-day.png) |
| ![لايت، ليلاً](docs/screenshots/lite-night.png) | ![سوبر، ليلاً](docs/screenshots/super-night.png) |

المكتبة الظاهرة في اللقطات **مخترَعة**: العناوين والقنوات والأغلفة كلها
مولَّدة، ولا يظهر فيها سيرفر حقيقي ولا حساب حقيقي.

## التنزيل

ملفات APK موقّعة تُنشر في
[صفحة الإصدارات](https://github.com/sagheerys/metube-mobile/releases)، ملفٌ
لكل تطبيق. سيطلب أندرويد إذنك بالتثبيت من هذا المصدر أول مرة؛ الإذن **لكل
تطبيق على حدة** ويمكنك سحبه بعدها.

والتطبيقان يحدّثان نفسيهما: **الإعدادات ← حول ← البحث عن تحديث** يجلب أحدث
إصدار ويسلّم الملف لمثبّت النظام. ولا يُثبَّت شيء إلا بتأكيدك.

أو ابنِه من المصدر، أدناه.

## المتطلبات

- سيرفر MeTube يمكن الوصول إليه (هذا عميل — لا ينزّل شيئاً بنفسه). وأربعة من
  إعداداته تغيّر سلوك التطبيقين، انظر
  **[docs/SERVER-SETUP.md](docs/SERVER-SETUP.md)**.
- أندرويد. `compileSdk 37`، والحد الأدنى يتبع افتراضي أدوات Flutter.
- Flutter **3.47.2** (‏Dart SDK ‏`^3.13.0`) للبناء من المصدر.

## البدء

```bash
git clone https://github.com/sagheerys/metube-mobile.git
cd metube-mobile
flutter pub get

# تصحيح
cd apps/metube_super && flutter run        # أو apps/metube_lite

# إصدار
cd apps/metube_super && flutter build apk --release
```

نسخ الإصدار تُوقَّع من `apps/<app>/android/key.properties` وهو **ليس** في هذا
المستودع. أنشئ مفاتيحك، أو ابنِ نسخة تصحيح.

عند أول تشغيل: **الإعدادات** ثم رابط السيرفر (واسم المستخدم وكلمة المرور إن
كان خلف مصادقة أساسية).

## البنية

```
packages/mt_core     Dart خالص: عميل واجهة MeTube، ومحرك التحميل، والتخزين،
                     والنسخ الاحتياطي، والسجلات — بلا أي استيراد من Flutter
packages/mt_media    التشغيل: معالج audio_service، ومصادر التشغيل، ومخازن
                     الموضع والحالة، والمشغل المصغر
packages/mt_ui       نظام تصميم «وهج»: الرموز، والثيمات، والودجات المشتركة،
                     والترجمة (ar/en)
apps/metube_lite     نسخة العائلة
apps/metube_super    نسخة مالك السيرفر
docs/                خريطة المستودع، وعقد السيرفر، ودليل إعداده
```

اتجاه الاعتماد في جهة واحدة: `apps → mt_media → mt_core`. و`mt_ui` لا يعرف
السيرفر، و`mt_core` لا يحوي كود Flutter.

## الاختبارات

```bash
cd packages/mt_core  && dart test              # ٣٦٢
cd packages/mt_media && flutter test           # ١١٥
cd packages/mt_ui    && flutter test           #  ٤٤
cd apps/metube_lite  && flutter test           #  ٦٩
cd apps/metube_super && flutter test           # ١٢١
```

**٧١١ اختباراً** حين كتابة هذا، ويُتوقَّع أن يكون `flutter analyze` نظيفاً.
عيّنات الاختبار من JSON سيرفر حقيقي، وكل عطل يُصلَح يترك خلفه اختباراً يسقط
على الكود القديم.

## الترجمة

لا نص مثبَّت في الواجهة: كل شيء في
`packages/mt_ui/lib/src/l10n/app_en.arb` و`app_ar.arb`.

إضافة لغة خطوتان — ملف `app_<code>.arb` جديد بجوارهما، وسطر واحد في
`packages/mt_ui/lib/src/l10n/language_names.dart` يحمل اسم اللغة **بلغتها
هي**. شاشة الإعدادات تبني قائمتها من `supportedLocales` فتظهر اللغة الجديدة
وحدها. ثم `cd packages/mt_ui && flutter gen-l10n`.

الترجمات مرحَّب بها جداً — راجع [CONTRIBUTING.md](CONTRIBUTING.md).

## الوثائق

| | |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | خريطة المستودع: الحزم، والقواعد التي تربطها، وأين تقع كل ميزة، وكيف تُشغَّل الاختبارات. إنجليزية أولاً وتحتها نسخة عربية. |
| [docs/SERVER-API.md](docs/SERVER-API.md) | عقد سيرفر MeTube: كل طلب واستجابة، ومخطط التخزين المحلي، والفخاخ التي كلّف اكتشافُ كلٍّ منها جلسة تنقيح. يُقرأ قبل أي كود شبكة أو تخزين. |
| [docs/SERVER-SETUP.md](docs/SERVER-SETUP.md) | كيف يُعدّ السيرفر، والإعدادات الأربعة التي يبدو غيابها عطلاً في التطبيق وليس كذلك. |
| [CONTRIBUTING.md](CONTRIBUTING.md) | ما يجب أن يستوفيه أي تعديل قبل قبوله. |
| [CHANGELOG.md](CHANGELOG.md) | ما تغيّر، إصداراً بإصدار. |
| [SECURITY.md](SECURITY.md) | كيف يُبلَّغ عن ثغرة. |

لغة العمل في المشروع عربية، والوثائق مكتوبة بالإنجليزية، والمشكلات وطلبات
الدمج مرحَّب بها بأي من اللغتين.

## شكر

- [MeTube](https://github.com/alexta69/metube) لـalexta69 — السيرفر الذي هذان
  التطبيقان عميلان له (AGPL-3.0).
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) — ما يستعمله MeTube للتنزيل فعلاً
  (Unlicense).
- فريقا Flutter وDart، ومؤلفو الحزم المذكورة في كل `pubspec.yaml`.

## الرخصة

[GPL-3.0](LICENSE) — حقوق النشر (C) 2026 ياسر صغير.

هذا برنامج حر: لك أن تعيد توزيعه و/أو تعدّله وفق شروط رخصة جنو العمومية
العامة كما نشرتها مؤسسة البرمجيات الحرة، الإصدار الثالث أو أي إصدار لاحق
تختاره. ويُوزَّع **بلا أي ضمان**؛ راجع الرخصة للتفاصيل.
