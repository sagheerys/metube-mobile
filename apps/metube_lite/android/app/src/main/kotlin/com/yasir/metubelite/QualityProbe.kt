package com.yasir.metubelite

import android.media.MediaExtractor
import android.media.MediaFormat

/**
 * **What a file actually is**: its video and audio tracks, from the header.
 *
 * The server records the quality a download was *asked* for ("best"), never
 * what it *got* — and on the owner's phone "best" was 4K AV1, which the chip
 * cannot decode in hardware. `MediaExtractor` lists the tracks without
 * decoding anything, and for a stream it reads the header with range
 * requests, so it costs one short request, only when the details sheet
 * asks. Separate from `MediaProbe`, which fills the library and must not
 * change for this.
 */
object QualityProbe {

    fun read(
        path: String?,
        url: String?,
        headers: Map<String, String>,
    ): Map<String, Any?> {
        val out = HashMap<String, Any?>()
        val extractor = MediaExtractor()
        try {
            when {
                path != null -> extractor.setDataSource(path)
                url != null -> extractor.setDataSource(url, headers)
                else -> return out
            }
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                // A cover picture can come as an "mjpeg" video track in an
                // audio file; it is not the video.
                if (mime.startsWith("video/") && mime != "video/mjpeg" &&
                    !out.containsKey("videoMime")
                ) {
                    out["videoMime"] = mime
                    var width = format.intOrNull(MediaFormat.KEY_WIDTH)
                    var height = format.intOrNull(MediaFormat.KEY_HEIGHT)
                    // "rotation-degrees" rather than KEY_ROTATION, which is
                    // API 23: a portrait phone clip is stored landscape.
                    val rotation = format.intOrNull("rotation-degrees") ?: 0
                    if (rotation == 90 || rotation == 270) {
                        val swap = width
                        width = height
                        height = swap
                    }
                    out["width"] = width
                    out["height"] = height
                    out["frameRate"] = format.numberOrNull(MediaFormat.KEY_FRAME_RATE)
                } else if (mime.startsWith("audio/") && !out.containsKey("audioMime")) {
                    out["audioMime"] = mime
                    out["sampleRate"] = format.intOrNull(MediaFormat.KEY_SAMPLE_RATE)
                    out["channels"] = format.intOrNull(MediaFormat.KEY_CHANNEL_COUNT)
                }
            }
        } catch (e: Throwable) {
            out["error"] = e.javaClass.simpleName + (e.message?.let { ": $it" } ?: "")
        } finally {
            try {
                extractor.release()
            } catch (_: Throwable) {
            }
        }
        return out
    }

    private fun MediaFormat.intOrNull(key: String): Int? =
        if (!containsKey(key)) null else try {
            getInteger(key)
        } catch (_: Throwable) {
            null
        }

    /** The frame rate is an integer in most containers and a float in some. */
    private fun MediaFormat.numberOrNull(key: String): Int? {
        if (!containsKey(key)) return null
        return try {
            getInteger(key)
        } catch (_: Throwable) {
            try {
                Math.round(getFloat(key))
            } catch (_: Throwable) {
                null
            }
        }
    }
}
