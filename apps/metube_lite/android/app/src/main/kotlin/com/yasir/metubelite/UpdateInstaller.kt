package com.yasir.metubelite

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * تثبيت التحديث الذاتي (م-66) — قناة `mtf/update`.
 *
 * **اسم القناة موحّد بين التطبيقين عمداً**: طبقة Dart فوقها متطابقة
 * حرفياً في Lite وSuper، فلا يتفرّع سلوك التحديث بينهما.
 *
 * التسليم بـ `content://` من `FileProvider` لا `file://`: أندرويد 7+
 * يرمي `FileUriExposedException` على الثاني، والأول يمنح مثبّت الحزم
 * إذناً مؤقتاً لهذا الملف وحده.
 */
object UpdateInstaller {
    private const val CHANNEL = "mtf/update"
    private const val APK_MIME = "application/vnd.android.package-archive"

    fun register(activity: Activity, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canInstall" -> result.success(canInstall(activity))
                    "openInstallSettings" ->
                        result.success(openInstallSettings(activity))
                    "install" -> install(activity, call.argument("path"), result)
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * أندرويد 8+ يجعل «تثبيت من مصادر غير معروفة» إذناً **لكل تطبيق**
     * لا مفتاحاً عاماً للنظام. بلا فحصه مسبقاً ينتهي المستخدم أمام
     * شاشة تثبيت مرفوضة بلا تفسير بعد تنزيل عشرات الميغابايت.
     */
    private fun canInstall(activity: Activity): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            activity.packageManager.canRequestPackageInstalls()

    private fun openInstallSettings(activity: Activity): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return try {
            activity.startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:" + activity.packageName),
                ),
            )
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }

    private fun install(
        activity: Activity,
        path: String?,
        result: MethodChannel.Result,
    ) {
        val file = if (path.isNullOrEmpty()) null else File(path)
        if (file == null || !file.exists()) {
            result.error("missing", "ملف التحديث غير موجود", null)
            return
        }
        val uri = FileProvider.getUriForFile(
            activity,
            activity.packageName + ".fileprovider",
            file,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, APK_MIME)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            activity.startActivity(intent)
            result.success(true)
        } catch (e: ActivityNotFoundException) {
            result.success(false)
        }
    }
}
