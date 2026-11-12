# Architecture

A map of the repository for someone who has just cloned it. It answers
three questions: what the pieces are, which rules hold them together, and
where a change belongs.

The Arabic version of this document follows the English one.

---

## 1. Three apps, one repository

| | **MeTube Lite** (Android) | **MeTube Super** (Android) | **MeTube Ember** (Windows) |
|---|---|---|---|
| Audience | Family and friends | The person who runs the server | The person who runs the server, at a computer |
| After a download finishes | Pulls the file to the phone, then **deletes it from the server** | **Keeps it on the server**, does not pull | **Keeps it on the server**; a clip can be kept on the computer too |
| Library | A scan of the local folder | `/history` and the local index, merged | `/history` and the local index, merged |
| Playback | Local files | Streams from the server, plus local | Streams from the server, plus local (`media_kit`) |
| Exclusive | An optional Wi-Fi-only rule, server cleanup | Tags, server switching, offline pinning, batch downloads | Super's features in a desktop layout: side panel, keyboard, floating player window |
| Accent colour | Petrol bay `#2F6D74` | Ember `#C25E2E` | Ember `#C25E2E`, as Super |

They are separate apps, not build flavours, and they diverge in behaviour
on purpose. Before changing anything in a shared package, ask: **does
this change the other apps?** The delete policy and the pull policy both
run through the same engine. A feature added to one app is matched in the
other two in the same change, or the change says why it does not apply.

## 2. Packages and the dependency rule

```
apps/metube_lite ─┐
                  ├─► packages/mt_media ─► packages/mt_core
apps/metube_super ┘            │                 ▲
        │                      └─► packages/mt_ui│
        └─► packages/mt_transcripts ─────────────┘

apps/metube_desktop ─► mt_core · mt_ui · mt_transcripts · mt_media
```

`apps/metube_desktop` is Ember. With Super it also uses
`package:mt_media/library.dart`, the merged library of the server owner's
apps. That entry is kept out of `mt_media.dart` because Lite has its own
library types with the same names.

| Package | Contains | Hard rule |
|---|---|---|
| `mt_core` | MeTube API client, models, download engine, storage, backup, URL tools | **Pure Dart. No Flutter import.** Tested with `dart test`. |
| `mt_media` | Audio handler, video playback, playback stores | Knows the server only through `mt_core` |
| `mt_ui` | Design tokens, themes, shared widgets, localisation | **Does not know the server exists** |
| `mt_transcripts` | Subtitle parsing, Arabic-aware search, the transcript store, fetching subtitles without disturbing the library | **Pure Dart. Super only**: Lite does not depend on it, so the family app cannot reach it |
| `apps/*` | Screens, routing, dependency injection | May depend on the packages above; Super and Ember on `mt_transcripts`, never Lite |
| `apps/metube_desktop/lib/platform/` | Everything specific to Windows | **The only place** that knows it runs on Windows; `mt_ui` learns it only through `MTDesktopApp` |

Three consequences worth remembering:

- **No `Dio` outside `MeTubeApiClient`.** Every call to the server goes
  through that one client. External services (YouTube page fetches,
  GitHub release checks) use the isolated helpers in
  `mt_core/src/resolvers/http_fetch.dart`, so a server credential header
  can never leak to a third party.
- **No hard-coded UI strings.** Every user-visible string lives in
  `packages/mt_ui/lib/src/l10n/app_en.arb` and `app_ar.arb`, and both
  files change in the same commit. A parity test enforces it.
- **No hard-coded colours or spacing.** Both come from
  `packages/mt_ui/lib/src/tokens/`. Each app has a day and a night
  palette; a literal colour works in daylight and breaks at night.

## 3. Where a feature lives

An app feature is a folder under `apps/<app>/lib/features/<name>/`:

```
features/update/
  update_state.dart      # Riverpod providers + the controller
  update_channel.dart    # platform channel wrapper, if any
  update_section.dart    # widget embedded in another screen
  update_sheet.dart      # bottom sheet
  widgets/               # anything larger than a small helper
```

Rules of thumb:

- Logic that does not need Flutter goes to `mt_core` and gets a
  `dart test`. That is where it can be tested exhaustively and cheaply.
- A widget used by more than one app goes to `mt_ui`. A widget used by one app,
  or one that reads app providers, stays in the app.
- Some files are deliberately duplicated between the two phone apps
  (`settings_state.dart`, `library_screen.dart`, `about_screen.dart`),
  and Ember has its own versions of most screens. When you edit one, edit
  its counterparts or say in the commit why not.
- **Size limits: 400 lines for a screen, 300 for anything else**,
  counting code and excluding comments. Passing the limit means the file
  should be split before the work is finished.

## 4. State and navigation

Riverpod handles dependency injection. `apps/<app>/lib/di.dart` is the
single wiring file: settings changes rebuild the API client and the
download engine automatically, with no manual synchronisation.

`apps/<app>/lib/router.dart` holds the whole route table using
`go_router`'s `StatefulShellRoute`. There is no direct `Navigator.push`
for a screen; sheets and dialogs are pushed normally.

Storage is `SharedPreferences` behind the `KeyValueStore` interface, so
`mt_core` can be tested with `MemoryKeyValueStore`. **Every
read-modify-write goes through `PrefsMutex`** — two concurrent flows
without the lock read the same value and the slower one erases the
faster one's write.

## 5. Running it

```bash
flutter pub get                      # once, at the repository root
flutter analyze --no-pub             # zero issues is the gate
cd packages/mt_core && dart test     # pure Dart core
cd packages/mt_transcripts && dart test
flutter test --no-pub                # in mt_media, mt_ui and the three apps
flutter build apk --debug            # in apps/metube_lite or apps/metube_super
flutter build windows --debug        # in apps/metube_desktop (Ember)
flutter test integration_test -d windows   # Ember's real player engine
```

After editing an `.arb` file, run `cd packages/mt_ui && flutter gen-l10n`.
Skipping it produces an `undefined_getter` at build time rather than at
edit time.

**Transcripts for clips downloaded earlier.** Super fetches a clip's
subtitles only before downloading it: a subtitles job for a clip already on
the server replaces the clip's record there. For the rest,
`dart run packages/mt_transcripts/bin/backfill.dart --server URL --languages ar,en`
reads the server's list, fetches subtitles with yt-dlp on your computer
(needs `curl_cffi` and ffmpeg), and writes one file to import in Super
(Settings, AI, Import). It resumes where it stopped, and a wrong option
prints the list of options.

The apps need a reachable [MeTube](https://github.com/alexta69/metube)
server. Enter its address in Settings on first launch.

## 6. Testing conventions

There are 436 test files. Four conventions matter:

- **Every fixed bug leaves a guard test** that fails on the old code.
  The proof is to reintroduce the broken code briefly and watch the test
  fall. Tests are never weakened to let a change through.
- **The device matrix.** `apps/*/test/device_matrix.dart` renders a
  widget across 16 screen sizes (phones, tablets upright and sideways, a
  foldable) and three text scales (1.0, 1.3, 2.0) and catches
  `RenderFlex overflowed` from the engine. Every new screen or sheet
  passes through `expectNoOverflow`. Layout is what breaks on other
  people's phones, and it does not show on the developer's. Ember has its
  own, `apps/metube_desktop/test/desktop_matrix.dart`: six window sizes
  from 960×600 to 2560×1440, the same text scales, in Arabic and English.
- **Localisation parity.** `packages/mt_ui/test/arb_parity_test.dart`
  fails if the two `.arb` files diverge in key count, translation or
  placeholders.
- **Real fixtures.** `packages/mt_core/test/fixtures/real/` holds
  captured server responses, anonymised: the identifying text is
  scrambled while length, character class, punctuation, URL hosts and
  file extensions are preserved, so every parsing edge case survives.

## 7. Deeper references

[`SERVER-API.md`](SERVER-API.md) is the one document to read before
writing any networking or storage code. It carries the full request and
response contract, the local storage schema, and the traps — each of
which cost a debugging session to find, and none of which can be
inferred from the server's own documentation.

---

# البنية المعمارية

خريطة المستودع لمن استنسخه للتو: ما القطع، وما القواعد التي تربطها، وأين
يقع أي تغيير.

## ١ · ثلاثة تطبيقات في مستودع واحد

| | **MeTube Lite** (أندرويد) | **MeTube Super** (أندرويد) | **MeTube Ember** (ويندوز) |
|---|---|---|---|
| لمن | العائلة والأصدقاء | من يدير الخادم | من يدير الخادم، على الحاسوب |
| بعد اكتمال التحميل | يسحب الملف للهاتف ثم **يحذفه من الخادم** | **يبقيه على الخادم** ولا يسحب | **يبقيه على الخادم**، ويمكن حفظ المقطع على الحاسوب أيضاً |
| المكتبة | مسح المجلد المحلي | `/history` والفهرس المحلي موحَّدين | `/history` والفهرس المحلي موحَّدين |
| التشغيل | ملفات محلية | بث من الخادم ومحلي | بث من الخادم ومحلي (`media_kit`) |
| الحصري | خيار الاقتصار على Wi‑Fi، تنظيف الخادم | الوسوم، تبديل الخادم، الإتاحة دون اتصال، الدفعي | مزايا Super بتخطيط الحاسوب: لوحة جانبية، ولوحة مفاتيح، ونافذة مشغّل عائمة |
| لون الفعل | خليج بترولي `#2F6D74` | وهج `#C25E2E` | وهج `#C25E2E` كـSuper |

تطبيقات مستقلة لا نكهات بناء، وتفترق في السلوك بقصد. وقبل أي تعديل في
حزمة مشتركة اسأل: **هل يغيّر هذا سلوك التطبيقين الآخرين؟** سياسة الحذف
وسياسة السحب تمرّان من المحرّك نفسه. والميزة التي تُضاف إلى تطبيق تُطابَق
في الآخرَين في التعديل نفسه، أو يُذكر لماذا لا تنطبق.

## ٢ · الحزم وقاعدة الاعتماد

```
apps/metube_lite ─┐
                  ├─► packages/mt_media ─► packages/mt_core
apps/metube_super ┘            │                 ▲
        │                      └─► packages/mt_ui│
        └─► packages/mt_transcripts ─────────────┘

apps/metube_desktop ─► mt_core · mt_ui · mt_transcripts · mt_media
```

`apps/metube_desktop` هو Ember. ويستعمل مع Super أيضاً
`package:mt_media/library.dart`، المكتبة الموحَّدة لتطبيقَي مالك الخادم.
وهذا المدخل خارج `mt_media.dart` لأن لـLite أنواع مكتبة خاصة بالأسماء
نفسها.

| الحزمة | تحتوي | القاعدة الصارمة |
|---|---|---|
| `mt_core` | عميل API، النماذج، محرك التحميل، التخزين، النسخ، أدوات الروابط | **Dart خالص بلا Flutter**، ويُختبر بـ`dart test` |
| `mt_media` | مشغّل الصوت والفيديو ومخازن التشغيل | لا يعرف الخادم إلا عبر `mt_core` |
| `mt_ui` | الرموز التصميمية والثيمات والودجات والترجمة | **لا يعرف أن للخادم وجوداً** |
| `mt_transcripts` | قراءة الترجمات، والبحث المراعي للعربية، ومخزن النصوص، وجلب الترجمة دون المساس بالمكتبة | **Dart خالص، وSuper وحده**: Lite لا يعتمد عليه فلا يصل إليه تطبيق العائلة |
| `apps/*` | الشاشات والتوجيه وحقن الاعتماديات | يعتمد على الحزم أعلاه، وSuper وEmber على `mt_transcripts`، لا Lite أبداً |
| `apps/metube_desktop/lib/platform/` | كل ما يخص ويندوز | **المكان الوحيد** الذي يعرف أنه على ويندوز، و`mt_ui` لا يعرفه إلا عبر `MTDesktopApp` |

ثلاث نتائج تستحق الحفظ:

- **لا `Dio` خارج `MeTubeApiClient`.** كل نداء للخادم يمرّ من هذا العميل
  وحده، والخدمات الخارجية تستعمل المساعدات المعزولة في
  `mt_core/src/resolvers/http_fetch.dart` — فلا تتسرّب ترويسة اعتماد
  الخادم إلى طرف ثالث أبداً.
- **صفر نص واجهة مثبَّت.** كل نص يعيش في ملفَّي `.arb`، ويتغيّران في
  الدفعة نفسها. حارس آلي يفرض ذلك.
- **صفر لون أو مسافة مثبَّتة.** كلاهما من `tokens`. لكل تطبيق لوحتان،
  نهارية وليلية، والقيمة المثبتة تعمل نهاراً وتنكسر ليلاً.

## ٣ · أين تقع الميزة

الميزة مجلَّد تحت `apps/<app>/lib/features/<name>/`. والقواعد العملية:

- ما لا يحتاج Flutter ينزل إلى `mt_core` ويأخذ `dart test`، فهناك
  يُختبر استقصاءً وبثمن زهيد.
- الودجت الذي يستعمله أكثر من تطبيق يذهب إلى `mt_ui`. وما يقرأ مزوّدات
  التطبيق يبقى في التطبيق.
- ملفات مكرَّرة بين تطبيقَي الجوال بقصد، ولـEmber نسخه الخاصة من أغلب
  الشاشات. إن عدّلت إحداها فعدّل نظيراتها أو علّل في الإيداع لماذا لا.
- **الحدّ: 400 سطر للشاشة و300 لغيرها**، كوداً بلا تعليقات. التجاوز
  يعني أن الملف يُفكَّك قبل إغلاق العمل.

## ٤ · الحالة والتنقّل

Riverpod يحقن الاعتماديات، وملف `di.dart` هو نقطة الربط الوحيدة: تغيّر
الإعدادات يعيد بناء العميل والمحرّك تلقائياً بلا تزامن يدوي.

`router.dart` يحمل جدول المسارات كاملاً بـ`go_router`. ولا
`Navigator.push` مباشر لشاشة.

التخزين `SharedPreferences` خلف واجهة `KeyValueStore`، **وكل
قراءة-تعديل-كتابة تمرّ من `PrefsMutex`**: تدفقان بلا قفل يقرآن القيمة
نفسها فيمحو البطيءُ كتابةَ الأسرع.

## ٥ · التشغيل

```bash
flutter pub get                      # مرة واحدة من الجذر
flutter analyze --no-pub             # صفر مشاكل هي البوابة
cd packages/mt_core && dart test     # النواة Dart خالص
cd packages/mt_transcripts && dart test
flutter test --no-pub                # في mt_media وmt_ui والتطبيقات الثلاثة
flutter build apk --debug            # داخل أحد تطبيقَي الجوال
flutter build windows --debug        # داخل apps/metube_desktop (Ember)
flutter test integration_test -d windows   # محرك تشغيل Ember الحقيقي
```

بعد تعديل أي `.arb`: `cd packages/mt_ui && flutter gen-l10n`. تخطّيها
يظهر `undefined_getter` عند البناء لا عند التحرير.

**نصوص المقاطع المحمَّلة سابقاً.** يجلب Super نص المقطع قبل تنزيله فقط، لأن
طلب الترجمة لمقطع موجود على السيرفر يستبدل سجلّه هناك. ولما سبق:
`dart run packages/mt_transcripts/bin/backfill.dart --server URL --languages ar,en`
يقرأ قائمة السيرفر، ويجلب الترجمات بـyt-dlp على حاسوبك (يحتاج `curl_cffi`
وffmpeg)، ويكتب ملفاً واحداً تستورده في Super (الإعدادات، النصوص،
استيراد). ويكمل من حيث توقف.

## ٦ · أعراف الاختبار

436 ملف اختبار، وأربعة أعراف تهمّ:

- **كل عطل يُصلَح يترك حارساً** يفشل على الكود القديم، ويُثبَت بإعادة
  الكود المعطوب مؤقتاً ومشاهدة الحارس يسقط. ولا يُضعَّف اختبار قائم
  لتمرير تعديل.
- **مصفوفة الأجهزة** في `apps/*/test/device_matrix.dart`: 16 مقاساً
  (جوالات، وتابلت قائماً وعرضياً، وقابل للطي) × ثلاثة مقاييس خط (1.0 و1.3
  و2.0)، تلتقط تجاوز الإطار من المحرّك. التخطيط هو ما ينكسر على هواتف
  الناس ولا يظهر على جهاز المطوّر. ولـEmber مصفوفته
  `apps/metube_desktop/test/desktop_matrix.dart`: ستة مقاسات نوافذ من
  960×600 إلى 2560×1440، بمقاييس الخط نفسها، بالعربية والإنجليزية.
- **تماثل الترجمة**: حارس يفشل إن اختلف الملفان في العدد أو الترجمة أو
  المعاملات.
- **fixtures حقيقية** معمّاة: النصّ المُعرِّف مُشوَّش، والطول وصنف
  الحروف وعلامات الترقيم والمضيفات والامتدادات محفوظة — فتبقى كل شواذّ
  التحليل قائمة.

## ٧ · المراجع الأعمق

[`SERVER-API.md`](SERVER-API.md) يُقرأ قبل أي كود شبكة أو تخزين. فيه عقد
الطلب والاستجابة كاملاً، ومخطط التخزين المحلي، والفخاخ التي كلّف اكتشافُ
كلٍّ منها جلسة تنقيح ولا يدلّ عليها توثيق الخادم نفسه.
