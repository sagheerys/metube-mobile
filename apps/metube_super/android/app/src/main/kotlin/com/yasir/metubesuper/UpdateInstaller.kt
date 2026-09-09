package com.yasir.metubesuper

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
 * Installing a self-update, over the `mtf/update` channel.
 *
 * **The channel name is deliberately the same in both apps**: the Dart layer
 * above it is literally identical in Lite and Super, so update behaviour
 * cannot drift between them.
 *
 * The APK is handed over as a `content://` URI from `FileProvider`, never as
 * `file://`: Android 7+ throws `FileUriExposedException` on the latter, while
 * the former grants the package installer a temporary permission for this one
 * file.
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
     * Since Android 8, "install from unknown sources" is a **per-application**
     * permission rather than one system-wide switch. Without checking it up
     * front, the user reaches a refused install screen with no explanation,
     * after downloading tens of megabytes.
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
            result.error("missing", "update file not found", null)
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
