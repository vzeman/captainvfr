package com.captainvfr.captainvfr

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class VibrationPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var vibrator: Vibrator? = null
    private val TAG = "VibrationPlugin"

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "captainvfr/vibration")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        
        // Initialize vibrator based on Android version
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        
        Log.d(TAG, "VibrationPlugin initialized - hasVibrator: ${vibrator?.hasVibrator()}")
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "hasVibrator" -> {
                result.success(vibrator?.hasVibrator() ?: false)
            }
            "vibrate" -> {
                val duration = call.argument<Int>("duration") ?: 100
                vibrate(duration.toLong())
                result.success(null)
            }
            "vibratePattern" -> {
                val pattern = call.argument<List<Int>>("pattern")
                val repeat = call.argument<Int>("repeat") ?: -1
                if (pattern != null) {
                    vibratePattern(pattern.map { it.toLong() }.toLongArray(), repeat)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "Pattern is required", null)
                }
            }
            "cancel" -> {
                cancelVibration()
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    private fun vibrate(duration: Long) {
        try {
            if (vibrator?.hasVibrator() == true) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    // Use VibrationEffect for Android O and above
                    val effect = VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE)
                    vibrator?.vibrate(effect)
                    Log.d(TAG, "Vibrating for ${duration}ms (Android O+)")
                } else {
                    // Use deprecated method for older versions
                    @Suppress("DEPRECATION")
                    vibrator?.vibrate(duration)
                    Log.d(TAG, "Vibrating for ${duration}ms (Legacy)")
                }
            } else {
                Log.w(TAG, "Device does not have a vibrator")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error during vibration", e)
        }
    }

    private fun vibratePattern(pattern: LongArray, repeat: Int) {
        try {
            if (vibrator?.hasVibrator() == true) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    // Use VibrationEffect for Android O and above
                    val effect = VibrationEffect.createWaveform(pattern, repeat)
                    vibrator?.vibrate(effect)
                    Log.d(TAG, "Vibrating with pattern (Android O+)")
                } else {
                    // Use deprecated method for older versions
                    @Suppress("DEPRECATION")
                    vibrator?.vibrate(pattern, repeat)
                    Log.d(TAG, "Vibrating with pattern (Legacy)")
                }
            } else {
                Log.w(TAG, "Device does not have a vibrator")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error during pattern vibration", e)
        }
    }

    private fun cancelVibration() {
        try {
            vibrator?.cancel()
            Log.d(TAG, "Vibration cancelled")
        } catch (e: Exception) {
            Log.e(TAG, "Error cancelling vibration", e)
        }
    }
}