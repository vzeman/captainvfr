package com.example.captainvfr

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

class BarometerPlugin: FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler, SensorEventListener {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null

    private var sensorManager: SensorManager? = null
    private var pressureSensor: Sensor? = null
    private var isListening = false

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "barometer_service")
        channel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "pressure_stream")
        eventChannel.setStreamHandler(this)

        val context = flutterPluginBinding.applicationContext
        sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        pressureSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_PRESSURE)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isBarometerAvailable" -> {
                result.success(pressureSensor != null)
            }
            "startPressureUpdates" -> {
                startPressureUpdates(result)
            }
            "stopPressureUpdates" -> {
                stopPressureUpdates(result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun startPressureUpdates(result: MethodChannel.Result) {
        if (pressureSensor == null) {
            result.error("UNAVAILABLE", "Pressure sensor not available", null)
            return
        }

        if (isListening) {
            result.success(null)
            return
        }

        val registered = sensorManager?.registerListener(
            this,
            pressureSensor,
            SensorManager.SENSOR_DELAY_NORMAL
        ) ?: false

        if (registered) {
            isListening = true
            result.success(null)
        } else {
            result.error("SENSOR_ERROR", "Failed to register pressure sensor listener", null)
        }
    }

    private fun stopPressureUpdates(result: MethodChannel.Result) {
        if (isListening) {
            sensorManager?.unregisterListener(this)
            isListening = false
        }
        result.success(null)
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type == Sensor.TYPE_PRESSURE && isListening) {
            val pressureHPa = event.values[0].toDouble()
            val timestamp = System.currentTimeMillis()

            val data = mapOf(
                "pressure" to pressureHPa,
                "timestamp" to timestamp
            )

            eventSink?.success(data)
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // Handle accuracy changes if needed
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        if (isListening) {
            sensorManager?.unregisterListener(this)
            isListening = false
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)

        if (isListening) {
            sensorManager?.unregisterListener(this)
            isListening = false
        }
    }
}
