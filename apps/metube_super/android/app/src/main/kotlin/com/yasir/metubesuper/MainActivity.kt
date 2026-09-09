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

// audio_service requires this base class instead of FlutterActivity, so that
// the media notification and the lock-screen buttons reach the player.
class MainActivity : AudioServiceActivity() {

    // The notification permission (Android 33+) for the media notification.
    // Super does not use `flutter_local_notifications` — it has no download
    // notifications — so asking over a native channel is cheaper than a whole
    // package for a single call.
    private val channel = "com.yasir.metubesuper/permissions"
    private val requestCode = 4301

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        UpdateInstaller.register(this, engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestNotifications" -> result.success(requestNotifications())
                    // Probing library items (duration, dimensions, cover) on
                    // a background thread. It reads the file header from the
                    // server with range requests, downloading nothing whole.
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
                    // **Open in an external player**, handed over as a `content://`
                    // URI from `FileProvider` rather than `file://`: Android 7+
                    // throws `FileUriExposedException` on the latter, while the
                    // former grants the chosen player **a temporary permission for
                    // this one file** — it sees nothing else and learns no path.
                    "openExternal" -> {
                        val path = call.argument<String>("path")
                        val mime = call.argument<String>("mime") ?: "video/*"
                        val file = if (path.isNullOrEmpty()) null else java.io.File(path)
                        if (file == null || !file.exists()) {
                            result.error("missing", "file not found", null)
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
                    // The launcher shortcut's destination, **consumed once**.
                    // Keeping it would re-run the shortcut on every return to the
                    // app.
                    "consumeShortcut" -> {
                        result.success(pendingShortcut)
                        pendingShortcut = null
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** The pending shortcut name, from the intent action `<pkg>.SHORTCUT_<NAME>`. */
    private var pendingShortcut: String? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        captureShortcut(intent)
    }

    // With `launchMode="singleTask"` a running app is not recreated, so the
    // new intent arrives here and nowhere else. Without this the shortcut
    // works exactly once.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureShortcut(intent)
    }

    /**
     * The destination comes from **the action name**, not from `data`: any
     * `data` in the intent is read by Flutter as an initial route, which is
     * why `metube://shortcut/shorts` used to end on "Page Not Found".
     */
    private fun captureShortcut(intent: Intent?) {
        val action = intent?.action ?: return
        val marker = ".SHORTCUT_"
        val at = action.indexOf(marker)
        if (at < 0) return
        pendingShortcut = action.substring(at + marker.length).lowercase()
    }

    /** true ⇔ the permission was already granted (or the platform is
     *  older than 33, where none is needed). */
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
