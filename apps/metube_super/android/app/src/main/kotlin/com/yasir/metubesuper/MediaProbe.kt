package com.yasir.metubesuper

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import java.io.File
import java.io.FileOutputStream

/**
 * Probing an item without playing it — **from a local file or straight from
 * the server's stream**.
 *
 * **Why the network too.** A real server returns no `thumbnail` field for any
 * item (measured: zero out of 252), and most of a Super library has no local
 * copy — so there is no source for a cover or for dimensions except the file
 * itself, on the server. `MediaMetadataRetriever` reads the header with range
 * requests rather than downloading the file, so on a local network the cost is
 * a fraction of a second.
 *
 * This is also what fills the shorts lane: dimensions used to be learned only
 * on first playback, which left the entire server library out of it ("the
 * reels only work if I play them once first").
 */
object MediaProbe {

    private const val MAX_EDGE = 480

    /**
     * Each entry of [items] carries a `key` (the storage key) and either a
     * `path` or a `url`; [headers] is optional and used for authentication.
     */
    fun scan(
        context: Context,
        items: List<Map<String, Any?>>,
        headers: Map<String, String>,
    ): List<Map<String, Any?>> {
        // **`filesDir`, not `cacheDir`.** Android wipes the cache under
        // storage pressure, which leaves the thumbnail paths in the index
        // pointing at files that are gone — empty cards that are **never
        // retried**, because the index says they have a cover. A 480px
        // thumbnail is about 30KB, so two hundred of them are about 6MB.
        val dir = File(context.filesDir, "thumbs").apply { mkdirs() }
        return items.map { probe(dir, it, headers) }
    }

    private fun probe(
        dir: File,
        item: Map<String, Any?>,
        headers: Map<String, String>,
    ): Map<String, Any?> {
        val out = HashMap<String, Any?>()
        val key = item["key"]?.toString() ?: return out
        out["key"] = key
        val path = item["path"]?.toString()
        val url = item["url"]?.toString()

        val retriever = MediaMetadataRetriever()
        try {
            // The cache name depends on the source: a file by its
            // modification time, a stream by its key.
            val target: File
            if (path != null) {
                val file = File(path)
                if (!file.exists()) {
                    out["error"] = "local file missing"
                    return out
                }
                retriever.setDataSource(path)
                target = File(dir, "${file.path.hashCode()}_${file.lastModified()}.jpg")
            } else if (url != null) {
                retriever.setDataSource(url, headers)
                target = File(dir, "n${key.hashCode()}.jpg")
            } else {
                return out
            }

            out["durationMs"] = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull()
            readSize(retriever, out)
            out["thumb"] = thumbnail(retriever, target)?.absolutePath
        } catch (e: Throwable) {
            // **No longer swallowed silently.** An unsupported codec or a
            // missing file used to pass with no trace in the log and none on
            // screen, which is how the thumbnail defect survived a month with
            // no stated cause. The reason now travels up to Dart.
            out["error"] = e.javaClass.simpleName +
                (e.message?.let { ": $it" } ?: "")
        } finally {
            try {
                retriever.release()
            } catch (_: Throwable) {
            }
        }
        return out
    }

    /** The dimensions **after** the recorded rotation is applied; without
     *  it, portrait clips are classified as landscape. */
    private fun readSize(r: MediaMetadataRetriever, out: HashMap<String, Any?>) {
        val w = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
            ?.toIntOrNull() ?: return
        val h = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
            ?.toIntOrNull() ?: return
        if (w <= 0 || h <= 0) return
        val rotation = r
            .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
            ?.toIntOrNull() ?: 0
        val swap = rotation == 90 || rotation == 270
        out["width"] = if (swap) h else w
        out["height"] = if (swap) w else h
    }

    private fun thumbnail(r: MediaMetadataRetriever, target: File): File? {
        if (target.exists() && target.length() > 0) return target
        val embedded = r.embeddedPicture
        val bitmap = if (embedded != null) {
            BitmapFactory.decodeByteArray(embedded, 0, embedded.size)
        } else {
            firstFrame(r)
        } ?: return null

        return try {
            FileOutputStream(target).use {
                scaled(bitmap).compress(Bitmap.CompressFormat.JPEG, 82, it)
            }
            target
        } catch (_: Throwable) {
            null
        } finally {
            bitmap.recycle()
        }
    }


    /**
     * Capturing a frame through a chain of fallbacks: some clips (HEVC
     * especially, and every clip whose header is read over the network) return
     * null for the first attempt while the second succeeds. Ordered from the
     * most accurate to the cheapest.
     */
    private fun firstFrame(r: MediaMetadataRetriever): Bitmap? {
        val attempts: List<() -> Bitmap?> = listOf(
            { r.getFrameAtTime(1_000_000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC) },
            { r.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC) },
            { r.getFrameAtTime(1_000_000, MediaMetadataRetriever.OPTION_CLOSEST) },
            { r.getFrameAtTime() },
        )
        for (attempt in attempts) {
            val frame = try {
                attempt()
            } catch (_: Throwable) {
                null
            }
            if (frame != null) return frame
        }
        return null
    }

    private fun scaled(source: Bitmap): Bitmap {
        val edge = maxOf(source.width, source.height)
        if (edge <= MAX_EDGE) return source
        val ratio = MAX_EDGE.toFloat() / edge
        return Bitmap.createScaledBitmap(
            source,
            (source.width * ratio).toInt().coerceAtLeast(1),
            (source.height * ratio).toInt().coerceAtLeast(1),
            true,
        )
    }
}
