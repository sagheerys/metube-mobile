package com.yasir.metubelite

import android.content.Intent
import android.media.MediaScannerConnection
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * audio_service يشترط هذه القاعدة بدل FlutterActivity ليصل إشعار الوسائط
 * وأزرار شاشة القفل إلى المشغل (م-21).
 *
 * وتحمل قناة `metube_lite/media` تسجيلَ الملف المكتمل في MediaStore (م-10)
 * ليظهر في معرض الهاتف. **انحراف موثق عن جدول حزم `02-TRD.md`:** الحزمة
 * المقترحة `media_scanner` مهجورة (بلا `namespace` المطلوب في AGP 8)،
 * والمطلوب منها نداء واحد من إطار أندرويد نفسه — فنُفِّذ هنا مباشرة بلا
 * اعتماد خارجي ولا مخاطرة بناء.
 */
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "metube_lite/media",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "scanFile" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrEmpty()) {
                        result.error("no_path", "path مطلوب", null)
                    } else {
                        // غير متزامن: يردّ بالـ URI بعد أن يفهرس النظام الملف.
                        MediaScannerConnection.scanFile(
                            applicationContext,
                            arrayOf(path),
                            null,
                        ) { _, uri -> runOnUiThread { result.success(uri?.toString()) } }
                    }
                }
                // م-18/م-35: سبر ملفات محلية (مدة + أبعاد + غلاف) على
                // خيط جانبي — 194 ملفاً على جهاز المالك تعني ثوانيَ من
                // فكّ الترميز، وتجميدُ خيط الواجهة لها غير مقبول.
                // **خيط واحد مشترك لا خيط لكل دفعة (إصلاح م-12):** كل
                // نداء كان يفتح خيطاً جديداً، ودفعات متتابعة (تحديث
                // المكتبة أثناء التمرير) تفتح خيوطاً بعدد النداءات.
                "probeMedia" -> {
                    val paths = call.argument<List<String>>("paths") ?: emptyList()
                    probeExecutor.execute {
                        val data = MediaProbe.scan(applicationContext, paths)
                        runOnUiThread { result.success(data) }
                    }
                }
                // **فتح في مشغل خارجي (طلب المالك 2026-09-05)** — بـ
                // `content://` من `FileProvider` لا `file://`: أندرويد 7+
                // يرمي `FileUriExposedException` على الثاني، والأول يمنح
                // المشغل المختار **إذناً مؤقتاً لهذا الملف وحده** فلا يرى
                // شيئاً آخر ولا يعرف مساره.
                "openExternal" -> {
                    val path = call.argument<String>("path")
                    val mime = call.argument<String>("mime") ?: "video/*"
                    val file = if (path.isNullOrEmpty()) null else java.io.File(path)
                    if (file == null || !file.exists()) {
                        result.error("missing", "الملف غير موجود", null)
                    } else {
                        val uri = androidx.core.content.FileProvider.getUriForFile(
                            this,
                            "$packageName.fileprovider",
                            file,
                        )
                        val view = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, mime)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        val chooser = Intent.createChooser(view, null).apply {
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        try {
                            startActivity(chooser)
                            result.success(true)
                        } catch (e: android.content.ActivityNotFoundException) {
                            result.success(false)
                        }
                    }
                }
                // م-41: وجهة اختصار الأيقونة — **تُستهلك مرة واحدة**.
                // إبقاؤها يعيد تنفيذ الاختصار عند كل عودة للتطبيق.
                "consumeShortcut" -> {
                    result.success(pendingShortcut)
                    pendingShortcut = null
                }
                else -> result.notImplemented()
            }
        }
    }

    /** اسم الاختصار المنتظر — من فعل النية `<pkg>.SHORTCUT_<NAME>`. */
    private var pendingShortcut: String? = null

    /** منفّذ سبر الوسائط — خيط واحد يخدم كل الدفعات بالترتيب. */
    private val probeExecutor: java.util.concurrent.ExecutorService =
        java.util.concurrent.Executors.newSingleThreadExecutor()

    override fun onDestroy() {
        probeExecutor.shutdown()
        super.onDestroy()
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        captureShortcut(intent)
    }

    // `launchMode="singleTask"`: التطبيق العامل لا يُعاد إنشاؤه، فالنية
    // الجديدة تصل هنا وحدها. بلا هذا يعمل الاختصار أول مرة فقط.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureShortcut(intent)
    }

    /**
     * الوجهة من **اسم الفعل** لا من `data` (خلل مصطاد على المحاكي
     * 2026-09-02): أي `data` في النية يقرؤها Flutter كمسار إقلاع،
     * فكان `metube://shortcut/shorts` ينتهي بـ «Page Not Found».
     */
    private fun captureShortcut(intent: Intent?) {
        val action = intent?.action ?: return
        val marker = ".SHORTCUT_"
        val at = action.indexOf(marker)
        if (at < 0) return
        pendingShortcut = action.substring(at + marker.length).lowercase()
    }
}
