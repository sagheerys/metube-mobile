package com.yasir.metubelite

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import java.io.File
import java.io.FileOutputStream

/**
 * Probing a local media file without playing it.
 *
 * **Why this exists at all.** A real server returns no `thumbnail` field for
 * any item (measured: zero out of 252), and Lite's migrated library is a set
 * of files on disk with no metadata beside them — so without this probe the
 * whole library has no covers, and the shorts lane stays empty because
 * dimensions used to be learned **only on first playback** ("the reels only
 * work if I play them once first").
 *
 * `MediaMetadataRetriever`, from the Android framework, gives all three in a
 * single open: the duration, the dimensions, and a cover — the embedded one
 * for audio, or a captured frame for video.
 */
object MediaProbe {

    /** The longest edge of a stored thumbnail; a library card is 98×62dp. */
    private const val MAX_EDGE = 480

    fun scan(context: Context, paths: List<String>): List<Map<String, Any?>> {
        // **`filesDir`, not `cacheDir`.** Android wipes the cache under
        // storage pressure, which leaves the thumbnail paths in the index
        // pointing at files that are gone — empty cards that are **never
        // retried**, because the index says they have a cover. A 480px
        // thumbnail is about 30KB, so two hundred of them are about 6MB.
        val dir = File(context.filesDir, "thumbs").apply { mkdirs() }
        return paths.map { probe(dir, it) }
    }

    private fun probe(dir: File, path: String): Map<String, Any?> {
        val out = HashMap<String, Any?>()
        out["path"] = path
        val file = File(path)
        if (!file.exists()) return out

        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(path)
            out["durationMs"] = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull()
            readSize(retriever, out)
            out["thumb"] = thumbnail(retriever, dir, file)?.absolutePath
        } catch (_: Throwable) {
            // A corrupt file, or a codec this device does not understand.
            // Skipped silently: the library shows the item without a cover
            // rather than failing the whole scan.
        } finally {
            try {
                retriever.release()
            } catch (_: Throwable) {
            }
        }
        return out
    }

    /**
     * The dimensions **after** the recorded rotation is applied. Portrait phone
     * clips are stored landscape with `rotation=90`, and without the swap they
     * are classified as landscape and drop out of the shorts lane, which
     * requires `aspectRatio < 1`.
     */
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

    /** The embedded cover first (audio), otherwise a captured frame (video). */
    private fun thumbnail(
        r: MediaMetadataRetriever,
        dir: File,
        file: File,
    ): File? {
        // The name carries the modification time, so a file replaced at the
        // same path produces a fresh cover.
        val target = File(dir, "${file.path.hashCode()}_${file.lastModified()}.jpg")
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
     * especially) return null for the first attempt while the second succeeds.
     * Ordered from the most accurate to the cheapest, starting one second in
     * because frame zero is black in a great many clips.
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
