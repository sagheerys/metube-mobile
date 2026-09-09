# Architecture

A map of the repository for someone who has just cloned it. It answers
three questions: what the pieces are, which rules hold them together, and
where a change belongs.

The Arabic version of this document follows the English one.

---

## 1. Two apps, one repository

| | **MeTube Lite** | **MeTube Super** |
|---|---|---|
| Audience | Family members | The person who runs the server |
| After a download finishes | Pulls the file to the phone, then **deletes it from the server** | **Keeps it on the server**, does not pull |
| Library | A scan of the local folder | `/history` and the local index, merged |
| Playback | Local files | Streams from the server, plus local |
| Exclusive | Wi-Fi-only transfers, server cleanup | Tags, server switching, offline pinning, batch downloads |
| Accent colour | Petrol bay `#2F6D74` | Ember `#C25E2E` |

They are separate apps, not build flavours. They share three packages and
diverge in behaviour on purpose. Before changing anything in a shared
package, ask: **does this change the other app?** The delete policy and
the pull policy both run through the same engine.

## 2. Packages and the dependency rule

```
apps/metube_lite ─┐
                  ├─► packages/mt_media ─► packages/mt_core
apps/metube_super ┘            │
                               └─► packages/mt_ui
```

| Package | Contains | Hard rule |
|---|---|---|
| `mt_core` | MeTube API client, models, download engine, storage, backup, URL tools | **Pure Dart. No Flutter import.** Tested with `dart test`. |
| `mt_media` | Audio handler, video playback, playback stores | Knows the server only through `mt_core` |
| `mt_ui` | Design tokens, themes, shared widgets, localisation | **Does not know the server exists** |
| `apps/*` | Screens, routing, dependency injection | May depend on all three |

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
- A widget used by both apps goes to `mt_ui`. A widget used by one app,
  or one that reads app providers, stays in the app.
- Some files are deliberately duplicated between the two apps
  (`settings_state.dart`, `library_screen.dart`, `about_screen.dart`).
  When you edit one, edit the other or say in the commit why not.
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
flutter test --no-pub                # in each of the other four packages
flutter build apk --debug            # in apps/metube_lite or apps/metube_super
```

After editing an `.arb` file, run `cd packages/mt_ui && flutter gen-l10n`.
Skipping it produces an `undefined_getter` at build time rather than at
edit time.

The apps need a reachable [MeTube](https://github.com/alexta69/metube)
server. Enter its address in Settings on first launch.

## 6. Testing conventions

There are 80 test files. Four conventions matter:

- **Every fixed bug leaves a guard test** that fails on the old code.
  The proof is to reintroduce the broken code briefly and watch the test
  fall. Tests are never weakened to let a change through.
- **The device matrix.** `apps/*/test/device_matrix.dart` renders a
  widget across five screen sizes and three text scales and catches
  `RenderFlex overflowed` from the engine. Every new screen or sheet
  passes through `expectNoOverflow`. Layout is what breaks on other
  people's phones, and it does not show on the developer's.
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

## ١ · تطبيقان في مستودع واحد

| | **MeTube Lite** | **MeTube Super** |
|---|---|---|
| لمن | العائلة | من يدير الخادم |
| بعد اكتمال التحميل | يسحب الملف للهاتف ثم **يحذفه من الخادم** | **يبقيه على الخادم** ولا يسحب |
| المكتبة | مسح المجلد المحلي | `/history` والفهرس المحلي موحَّدين |
| التشغيل | ملفات محلية | بث من الخادم ومحلي |
| الحصري | التحميل على Wi‑Fi فقط، تنظيف الخادم | الوسوم، تبديل الخادم، الإتاحة دون اتصال، الدفعي |
| لون الفعل | خليج بترولي `#2F6D74` | وهج `#C25E2E` |

تطبيقان مستقلان لا نكهتا بناء. يتقاسمان ثلاث حزم ويفترقان في السلوك
بقصد. وقبل أي تعديل في حزمة مشتركة اسأل: **هل يغيّر هذا سلوك التطبيق
الآخر؟** سياسة الحذف وسياسة السحب تمرّان من المحرّك نفسه.

## ٢ · الحزم وقاعدة الاعتماد

```
apps/metube_lite ─┐
                  ├─► packages/mt_media ─► packages/mt_core
apps/metube_super ┘            │
                               └─► packages/mt_ui
```

| الحزمة | تحتوي | القاعدة الصارمة |
|---|---|---|
| `mt_core` | عميل API، النماذج، محرك التحميل، التخزين، النسخ، أدوات الروابط | **Dart خالص بلا Flutter**، ويُختبر بـ`dart test` |
| `mt_media` | مشغّل الصوت والفيديو ومخازن التشغيل | لا يعرف الخادم إلا عبر `mt_core` |
| `mt_ui` | الرموز التصميمية والثيمات والودجات والترجمة | **لا يعرف أن للخادم وجوداً** |
| `apps/*` | الشاشات والتوجيه وحقن الاعتماديات | يعتمد على الثلاث |

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
- الودجت الذي يستعمله التطبيقان يذهب إلى `mt_ui`. وما يقرأ مزوّدات
  التطبيق يبقى في التطبيق.
- ملفات مكرَّرة بين التطبيقين بقصد. إن عدّلت إحداها فعدّل أختها أو علّل
  في الإيداع لماذا لا.
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
flutter test --no-pub                # في الحزم الأربع الأخرى
flutter build apk --debug            # داخل أحد التطبيقين
```

بعد تعديل أي `.arb`: `cd packages/mt_ui && flutter gen-l10n`. تخطّيها
يظهر `undefined_getter` عند البناء لا عند التحرير.

## ٦ · أعراف الاختبار

ثمانون ملف اختبار، وأربعة أعراف تهمّ:

- **كل عطل يُصلَح يترك حارساً** يفشل على الكود القديم، ويُثبَت بإعادة
  الكود المعطوب مؤقتاً ومشاهدة الحارس يسقط. ولا يُضعَّف اختبار قائم
  لتمرير تعديل.
- **مصفوفة الأجهزة** في `apps/*/test/device_matrix.dart`: خمسة مقاسات ×
  ثلاثة مقاييس خط، تلتقط تجاوز الإطار من المحرّك. التخطيط هو ما ينكسر
  على هواتف الناس ولا يظهر على جهاز المطوّر.
- **تماثل الترجمة**: حارس يفشل إن اختلف الملفان في العدد أو الترجمة أو
  المعاملات.
- **fixtures حقيقية** معمّاة: النصّ المُعرِّف مُشوَّش، والطول وصنف
  الحروف وعلامات الترقيم والمضيفات والامتدادات محفوظة — فتبقى كل شواذّ
  التحليل قائمة.

## ٧ · المراجع الأعمق

[`SERVER-API.md`](SERVER-API.md) يُقرأ قبل أي كود شبكة أو تخزين. فيه عقد
الطلب والاستجابة كاملاً، ومخطط التخزين المحلي، والفخاخ التي كلّف اكتشافُ
كلٍّ منها جلسة تنقيح ولا يدلّ عليها توثيق الخادم نفسه.
