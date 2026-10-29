package com.speedometer.speedometer_app

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.view.Surface
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity: FlutterActivity(), SensorEventListener {
    private val COMPASS_CHANNEL = "com.speedometer.app/compass"
    private var sensorManager: SensorManager? = null
    private var rotationSensor: Sensor? = null
    private var eventSink: EventChannel.EventSink? = null

    private val rotationMatrix = FloatArray(9)
    private val outRotationMatrix = FloatArray(9)
    private val orientationValues = FloatArray(3)
    private var lastEmittedHeading: Double = -1.0
    private var lastEmittedTime: Long = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        // Prefer ROTATION_VECTOR (gyro + accel + magnetometer sensor fusion) for instantaneous rotation
        rotationSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
            ?: sensorManager?.getDefaultSensor(Sensor.TYPE_ORIENTATION)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, COMPASS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    rotationSensor?.let {
                        sensorManager?.registerListener(
                            this@MainActivity,
                            it,
                            SensorManager.SENSOR_DELAY_GAME
                        )
                    }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    sensorManager?.unregisterListener(this@MainActivity)
                }
            }
        )
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null || eventSink == null) return

        val now = System.currentTimeMillis()
        // Responsive 30-40 FPS update rate (every ~25ms)
        if (now - lastEmittedTime < 25) return

        var heading = 0.0

        if (event.sensor.type == Sensor.TYPE_ROTATION_VECTOR) {
            SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)

            @Suppress("DEPRECATION")
            val rotation = windowManager.defaultDisplay.rotation
            when (rotation) {
                Surface.ROTATION_90 -> {
                    SensorManager.remapCoordinateSystem(
                        rotationMatrix,
                        SensorManager.AXIS_Y,
                        SensorManager.AXIS_MINUS_X,
                        outRotationMatrix
                    )
                }
                Surface.ROTATION_270 -> {
                    SensorManager.remapCoordinateSystem(
                        rotationMatrix,
                        SensorManager.AXIS_MINUS_Y,
                        SensorManager.AXIS_X,
                        outRotationMatrix
                    )
                }
                else -> {
                    System.arraycopy(rotationMatrix, 0, outRotationMatrix, 0, 9)
                }
            }

            SensorManager.getOrientation(outRotationMatrix, orientationValues)
            val azimuthRad = orientationValues[0]
            heading = (Math.toDegrees(azimuthRad.toDouble()) + 360.0) % 360.0
        } else if (event.sensor.type == Sensor.TYPE_ORIENTATION) {
            heading = (event.values[0].toDouble() - 90.0 + 360.0) % 360.0
        }

        if (Math.abs(heading - lastEmittedHeading) >= 0.3) {
            lastEmittedHeading = heading
            lastEmittedTime = now
            eventSink?.success(heading)
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onDestroy() {
        sensorManager?.unregisterListener(this)
        super.onDestroy()
    }
}
