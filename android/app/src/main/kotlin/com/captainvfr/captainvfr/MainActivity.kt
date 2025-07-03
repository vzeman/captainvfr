package com.captainvfr.captainvfr

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Register the AltitudePlugin using the new Flutter embedding
        flutterEngine.plugins.add(AltitudePlugin())
    }
}
