package com.captainvfr.captainvfr

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Register the AltitudePlugin
        AltitudePlugin().apply {
            this.onAttachedToEngine(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
        }
    }
}

// Extension function to register the plugin with the binary messenger and context
private fun AltitudePlugin.onAttachedToEngine(messenger: io.flutter.plugin.common.BinaryMessenger, context: Context) {
    val channel = MethodChannel(messenger, "altitude_service")
    channel.setMethodCallHandler(this)
    
    // Set up event channel
    val eventChannel = EventChannel(messenger, "altitude_service/updates")
    eventChannel.setStreamHandler(this)
    
    // Initialize sensor manager
    val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
    val fieldSensorManager = this::class.java.getDeclaredField("sensorManager")
    fieldSensorManager.isAccessible = true
    fieldSensorManager.set(this, sensorManager)
    
    val pressureSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_PRESSURE)
    val fieldPressureSensor = this::class.java.getDeclaredField("pressureSensor")
    fieldPressureSensor.isAccessible = true
    fieldPressureSensor.set(this, pressureSensor)
    
    // Create a background thread for sensor updates
    val sensorThread = HandlerThread("SensorThread").apply { start() }
    val fieldSensorThread = this::class.java.getDeclaredField("sensorThread")
    fieldSensorThread.isAccessible = true
    fieldSensorThread.set(this, sensorThread)
    
    val sensorHandler = Handler(sensorThread.looper)
    val fieldSensorHandler = this::class.java.getDeclaredField("sensorHandler")
    fieldSensorHandler.isAccessible = true
    fieldSensorHandler.set(this, sensorHandler)
}
