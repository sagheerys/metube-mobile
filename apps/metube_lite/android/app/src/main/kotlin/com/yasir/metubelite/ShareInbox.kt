package com.yasir.metubelite

import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Text shared into the app, held until Dart takes it.
 *
 * This replaces the `receive_sharing_intent` package, which treated the
 * activity's intent as a fresh share every time the activity attached. With
 * `singleTask` and the task left in Recents after the process died, Android
 * rebuilds the activity with the task's **original** intent (the share that
 * opened the previous session) and hands the new share to `onNewIntent`
 * before Dart listens. The package dropped the new share and replayed the old
 * one, so sharing a clip opened the previous clip instead, and opening the
 * app with no share at all could show a sheet.
 *
 * Two rules fix both: a share counts only when it is new (not a restored
 * activity, not a relaunch from Recents), and it waits here until Dart pulls
 * it, so a share that lands while the engine is still starting is not lost.
 */
object ShareInbox {
    private const val CHANNEL = "metube/share"

    /**
     * The texts of the newest share not yet taken. **The newest replaces an
     * older one** rather than queueing behind it: two shares inside the
     * start-up window would otherwise arrive as one batch of two links, and a
     * batch is downloaded at once with no sheet to choose from.
     */
    private var pending: List<String>? = null

    private var channel: MethodChannel? = null

    /** Called from `configureFlutterEngine`, once per activity. */
    fun register(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "take" -> {
                        result.success(pending ?: emptyList<String>())
                        pending = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    /**
     * Keeps [intent]'s text if it is a new share, and tells Dart to come for
     * it. [restored] is true when the activity is rebuilt from saved state:
     * its intent is then the old one, and any new share follows through
     * `onNewIntent`.
     */
    fun offer(intent: Intent?, restored: Boolean) {
        if (intent == null || restored) return
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return
        val texts = textsOf(intent)
        if (texts.isEmpty()) return
        pending = texts
        // A fresh engine has no Dart handler yet and ignores this; it takes
        // the share itself once the shell starts listening.
        channel?.invokeMethod("arrived", null)
    }

    private fun textsOf(intent: Intent): List<String> = when (intent.action) {
        Intent.ACTION_SEND ->
            listOfNotNull(intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString())
        Intent.ACTION_SEND_MULTIPLE ->
            intent.getCharSequenceArrayListExtra(Intent.EXTRA_TEXT)
                ?.map { it.toString() }
                .orEmpty()
        else -> emptyList()
    }.filter { it.isNotBlank() }
}
