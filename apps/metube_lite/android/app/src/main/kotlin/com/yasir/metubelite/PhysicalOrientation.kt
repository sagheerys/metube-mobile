package com.yasir.metubelite

import android.content.Context
import android.hardware.SensorManager
import android.view.OrientationEventListener
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel

/**
 * How the phone is really held, on the `mt/orientation` channel the app's
 * Dart side shares with the other app: "portrait" or "landscape", sent when
 * it changes, the first reading as soon as it is known.
 *
 * **Read from the motion sensor, not the screen**: while the player keeps
 * the screen upright after full screen, the screen says portrait however
 * the phone is held. YouTube gives rotation back only once the phone has
 * really been turned upright, and so does the player, with this.
 *
 * Between the two (a phone tilted halfway, upside down, or flat on a table)
 * nothing is sent: the last position stands.
 */
object PhysicalOrientation {
    fun register(context: Context, messenger: BinaryMessenger) {
        EventChannel(messenger, "mt/orientation").setStreamHandler(Handler(context))
    }

    private class Handler(private val context: Context) : EventChannel.StreamHandler {
        private var listener: OrientationEventListener? = null

        override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
            var last: String? = null
            val sensor = object : OrientationEventListener(context, SensorManager.SENSOR_DELAY_UI) {
                override fun onOrientationChanged(angle: Int) {
                    if (angle == ORIENTATION_UNKNOWN) return
                    val now = when {
                        angle <= 30 || angle >= 330 -> "portrait"
                        angle in 60..120 || angle in 240..300 -> "landscape"
                        else -> return
                    }
                    if (now != last) {
                        last = now
                        events.success(now)
                    }
                }
            }
            if (!sensor.canDetectOrientation()) {
                events.error("no_sensor", "this device cannot tell how it is held", null)
                return
            }
            sensor.enable()
            listener = sensor
        }

        override fun onCancel(arguments: Any?) {
            listener?.disable()
            listener = null
        }
    }
}
