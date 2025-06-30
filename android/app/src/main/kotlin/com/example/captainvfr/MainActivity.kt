package com.example.captainvfr

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register native plugins
        flutterEngine.plugins.add(AltitudePlugin())
        flutterEngine.plugins.add(BarometerPlugin())
    }
}
