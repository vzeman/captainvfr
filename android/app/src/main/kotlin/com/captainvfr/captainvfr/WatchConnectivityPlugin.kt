package com.captainvfr.captainvfr

import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Stub implementation of WatchConnectivityPlugin for Android.
 * Since Android doesn't have watch connectivity like iOS, this just provides
 * a no-op implementation to prevent MissingPluginException.
 */
class WatchConnectivityPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel

    companion object {
        private const val TAG = "WatchConnectivity"
        private const val CHANNEL_NAME = "com.captainvfr.watch_connectivity"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "sendTrackingState" -> {
                // No-op on Android - no watch to send to
                Log.d(TAG, "sendTrackingState called (no-op on Android)")
                result.success(null)
            }
            "sendFlightData" -> {
                // No-op on Android - no watch to send to
                Log.d(TAG, "sendFlightData called (no-op on Android)")
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }
}