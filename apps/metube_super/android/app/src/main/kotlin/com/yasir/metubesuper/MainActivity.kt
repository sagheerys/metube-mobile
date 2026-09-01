package com.yasir.metubesuper

import android.Manifest
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
                    else -> result.notImplemented()
                }
            }
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
