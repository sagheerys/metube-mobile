package com.yasir.metubelite

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
                "probeMedia" -> {
                    val paths = call.argument<List<String>>("paths") ?: emptyList()
                    Thread {
                        val data = MediaProbe.scan(applicationContext, paths)
                        runOnUiThread { result.success(data) }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }
}
