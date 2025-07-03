package com.captainvfr.captainvfr

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.HandlerThread
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class AltitudePlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var channel: MethodChannel
    private var eventSink: EventChannel.EventSink? = null
    private var sensorManager: SensorManager? = null
    private var pressureSensor: Sensor? = null
    private var sensorEventListener: SensorEventListener? = null
    private var sensorHandler: Handler? = null
    private var sensorThread: HandlerThread? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "altitude_service")
        channel.setMethodCallHandler(this)

        // Set up event channel
        EventChannel(flutterPluginBinding.binaryMessenger, "altitude_service/updates").setStreamHandler(this)

        // Initialize sensor manager
        sensorManager = flutterPluginBinding.applicationContext.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        pressureSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_PRESSURE)
        
        // Create a background thread for sensor updates
        sensorThread = HandlerThread("SensorThread").apply { start() }
        sensorHandler = Handler(sensorThread!!.looper)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "isBarometerAvailable" -> {
                result.success(pressureSensor != null)
            }
            "startPressureUpdates" -> {
                if (pressureSensor == null) {
                    result.error("UNAVAILABLE", "Barometer is not available on this device", null)
                } else {
                    startPressureUpdates()
                    result.success(null)
                }
            }
            "stopPressureUpdates" -> {
                stopPressureUpdates()
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun startPressureUpdates() {
        if (sensorEventListener != null) return // Already listening

        sensorEventListener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                if (event.sensor.type == Sensor.TYPE_PRESSURE) {
                    // Pressure is in hPa (millibars)
                    val pressureHpa = event.values[0]
                    // Send pressure update to Flutter
                    sensorHandler?.post {
                        eventSink?.success(pressureHpa)
                    }
                }
            }

            override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {
                // Handle accuracy changes if needed
            }
        }

        // Register the listener with a delay of 200,000 microseconds (200ms)
        sensorManager?.registerListener(
            sensorEventListener,
            pressureSensor,
            SensorManager.SENSOR_DELAY_NORMAL,
            sensorHandler
        )
    }

    private fun stopPressureUpdates() {
        sensorEventListener?.let { listener ->
            sensorManager?.unregisterListener(listener)
        }
        sensorEventListener = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        stopPressureUpdates()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        stopPressureUpdates()
        sensorThread?.quitSafely()
        sensorThread = null
        sensorHandler = null
    }
}
