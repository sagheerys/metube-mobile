package com.yasir.metubesuper

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// audio_service يشترط هذه القاعدة بدل FlutterActivity ليصل إشعار
// الوسائط وأزرار شاشة القفل إلى المشغل (م-21).
class MainActivity : AudioServiceActivity() {

    // إذن الإشعارات (33+) لإشعار الوسائط. Super لا يستعمل
    // `flutter_local_notifications` (لا إشعارات تحميل فيه)، فطلب الإذن
    // بقناة أصلية أرخص من حزمة كاملة لنداء واحد.
    private val channel = "com.yasir.metubesuper/permissions"
    private val requestCode = 4301

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        UpdateInstaller.register(this, engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestNotifications" -> result.success(requestNotifications())
                    // م-18/م-35: سبر عناصر المكتبة (مدة + أبعاد + غلاف)
                    // على خيط جانبي — يقرأ ترويسة الملف من السيرفر
                    // بطلبات نطاق، فلا ينزّل شيئاً كاملاً.
                    "probeMedia" -> {
                        val items = call.argument<List<Map<String, Any?>>>("items")
                            ?: emptyList()
                        val headers = call.argument<Map<String, String>>("headers")
                            ?: emptyMap()
                        Thread {
                            val data = MediaProbe.scan(applicationContext, items, headers)
                            runOnUiThread { result.success(data) }
                        }.start()
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

    /** true ⇔ الإذن ممنوح أصلاً (أو النسخة أقدم من 33 فلا إذن مطلوب). */
    private fun requestNotifications(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        val granted = ContextCompat.checkSelfPermission(
            this, Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
        if (!granted) {
            ActivityCompat.requestPermissions(
                this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), requestCode
            )
        }
        return granted
    }
}
