package com.yasir.metubelite

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import java.io.File
import java.io.FileOutputStream

/**
 * م-18 + م-35: سبر ملف وسائط محلي بلا تشغيله.
 *
 * **لماذا أصلاً:** سيرفر المالك لا يرجع حقل `thumbnail` لأي عنصر (فُحص:
 * صفر من 252)، ومكتبة Lite المهاجَرة ملفاتٌ على القرص بلا أي بيانات —
 * فبلا هذا السبر تبقى المكتبة كلها بلا أغلفة، ويبقى «مسار القِصار»
 * فارغاً لأن الأبعاد كانت تُتعلَّم **عند أول تشغيل فقط** (خلل مصطاد على
 * جهاز المالك 2026-09-01: «الريلز لا تعمل إلا إذا شغّلتها أول مرة»).
 *
 * `MediaMetadataRetriever` من إطار أندرويد يعطي الثلاثة في فتحة واحدة:
 * المدة، والأبعاد، وغلافاً — المضمّن للصوت أو لقطة إطار للفيديو.
 */
object MediaProbe {

    /** أقصى ضلع للمصغرة المحفوظة — بطاقة المكتبة 98×62 نقطة. */
    private const val MAX_EDGE = 480

    fun scan(context: Context, paths: List<String>): List<Map<String, Any?>> {
        val dir = File(context.cacheDir, "thumbs").apply { mkdirs() }
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
            // ملف تالف أو ترميز لا يفهمه الجهاز — يُتجاوز بصمت: المكتبة
            // تعرض العنصر بلا غلاف بدل أن يسقط المسح كله.
        } finally {
            try {
                retriever.release()
            } catch (_: Throwable) {
            }
        }
        return out
    }

    /**
     * الأبعاد **بعد** تطبيق دوران التسجيل: مقاطع الجوال العمودية تُخزَّن
     * أفقياً مع `rotation=90`، وبدون القلب تُصنَّف عرضية فتسقط من مسار
     * القِصار الذي يشترط `aspectRatio < 1`.
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

    /** الغلاف المضمّن أولاً (الصوت)، وإلا لقطة إطار (الفيديو). */
    private fun thumbnail(
        r: MediaMetadataRetriever,
        dir: File,
        file: File,
    ): File? {
        // الاسم يحمل زمن التعديل: ملف استُبدل بنفس المسار يولّد غلافاً جديداً.
        val target = File(dir, "${file.path.hashCode()}_${file.lastModified()}.jpg")
        if (target.exists() && target.length() > 0) return target

        val embedded = r.embeddedPicture
        val bitmap = if (embedded != null) {
            BitmapFactory.decodeByteArray(embedded, 0, embedded.size)
        } else {
            // ثانية واحدة: الإطار صفر أسود في كثير من المقاطع.
            r.getFrameAtTime(1_000_000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                ?: r.getFrameAtTime()
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
