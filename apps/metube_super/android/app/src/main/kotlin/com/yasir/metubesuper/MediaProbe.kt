package com.yasir.metubesuper

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import java.io.File
import java.io.FileOutputStream

/**
 * م-18 + م-35 لـ Super: سبر عنصر بلا تشغيله — **من ملف محلي أو من بثّ
 * السيرفر مباشرة**.
 *
 * **لماذا الشبكة أيضاً:** سيرفر المالك لا يرجع حقل `thumbnail` لأي عنصر
 * (فُحص: صفر من 252)، ومعظم مكتبته إنستقرام بلا نسخة محلية — فلا مصدر
 * للغلاف ولا للأبعاد إلا الملف نفسه على السيرفر.
 * `MediaMetadataRetriever` يقرأ الترويسة بطلبات نطاق (Range) ولا ينزّل
 * الملف كاملاً، فالكلفة على الشبكة المحلية أجزاء من الثانية.
 *
 * هذا هو أيضاً ما يملأ «مسار القِصار»: الأبعاد كانت تُتعلَّم عند أول
 * تشغيل فقط، فمكتبة السيرفر كلها خارج المسار (بلاغ المالك: «الريلز لا
 * تعمل إلا إذا شغّلتها أول مرة»).
 */
object MediaProbe {

    private const val MAX_EDGE = 480

    /**
     * [items] لكل عنصر: `key` (مفتاح التخزين)، و`path` أو `url`،
     * و`headers` اختيارية للمصادقة.
     */
    fun scan(
        context: Context,
        items: List<Map<String, Any?>>,
        headers: Map<String, String>,
    ): List<Map<String, Any?>> {
        val dir = File(context.cacheDir, "thumbs").apply { mkdirs() }
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
            // اسم المخبأ يعتمد المصدر: الملف بزمن تعديله، والبثّ بمفتاحه.
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
            // **لم يعد يُبتلع بصمت** (م-47): ترميز غير مدعوم أو ملف
            // مفقود كان يمرّ بلا أثر في السجل ولا في الشاشة، فبقي عطل
            // المصغرات شهراً بلا سبب معلن. الآن يصعد السبب إلى دارت.
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

    /** الأبعاد **بعد** تطبيق دوران التسجيل — بدونه يُصنّف العمودي أفقياً. */
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
     * لقطة إطار بسلسلة بدائل: بعض المقاطع (HEVC خاصة، وكل مقطع تُقرأ
     * ترويسته من الشبكة) تُرجع null لأول محاولة بينما تنجح الثانية.
     * الترتيب من الأدق للأرخص.
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
