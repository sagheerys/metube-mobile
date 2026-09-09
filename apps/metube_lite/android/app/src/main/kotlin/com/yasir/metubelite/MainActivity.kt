package com.yasir.metubelite

import android.content.Intent
import android.media.MediaScannerConnection
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * audio_service requires this base class instead of FlutterActivity, so that
 * the media notification and the lock-screen buttons reach the player.
 *
 * The `metube_lite/media` channel also registers a finished download in
 * MediaStore, so it shows up in the phone's gallery. **A deliberate departure
 * from the planned package list:** the obvious package, `media_scanner`, is
 * abandoned (it lacks the `namespace` that AGP 8 requires), and all that is
 * needed from it is a single call into the Android framework — so it is done
 * here directly, with no external dependency and no build risk.
 */
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        UpdateInstaller.register(this, flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "metube_lite/media",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "scanFile" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrEmpty()) {
                        result.error("no_path", "path is required", null)
                    } else {
                        // Asynchronous: answers with the URI once the
                        // system has indexed the file.
                        MediaScannerConnection.scanFile(
                            applicationContext,
                            arrayOf(path),
                            null,
                        ) { _, uri -> runOnUiThread { result.success(uri?.toString()) } }
                    }
                }
                // Probing local files (duration, dimensions, cover) on a
                // background thread: a couple of hundred files means seconds
                // of decoding, and freezing the UI thread for that is not
                // acceptable.
                // **One shared thread rather than one per batch:** every call
                // used to open a new thread, and back-to-back batches (a
                // library refresh during a scroll) opened as many threads as
                // there were calls.
                "probeMedia" -> {
                    val paths = call.argument<List<String>>("paths") ?: emptyList()
                    probeExecutor.execute {
                        val data = MediaProbe.scan(applicationContext, paths)
                        runOnUiThread { result.success(data) }
                    }
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

    /** The media probe executor: one thread serving every batch in order. */
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
}
