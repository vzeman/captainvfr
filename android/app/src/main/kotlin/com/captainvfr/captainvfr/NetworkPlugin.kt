package com.captainvfr.captainvfr

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class NetworkPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val TAG = "NetworkPlugin"

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "captainvfr/network")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        
        // Log initial network state
        logNetworkState()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "checkNetworkStatus" -> {
                val status = checkNetworkStatus()
                result.success(status)
            }
            "getNetworkDiagnostics" -> {
                val diagnostics = getNetworkDiagnostics()
                result.success(diagnostics)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    private fun checkNetworkStatus(): Map<String, Any> {
        val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val result = mutableMapOf<String, Any>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val network = connectivityManager.activeNetwork
            val capabilities = connectivityManager.getNetworkCapabilities(network)
            
            result["isConnected"] = network != null
            result["hasInternet"] = capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) ?: false
            result["hasValidated"] = capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) ?: false
            
            when {
                capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true -> {
                    result["connectionType"] = "WiFi"
                }
                capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true -> {
                    result["connectionType"] = "Cellular"
                }
                capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) == true -> {
                    result["connectionType"] = "Ethernet"
                }
                else -> {
                    result["connectionType"] = "Unknown"
                }
            }
        } else {
            @Suppress("DEPRECATION")
            val networkInfo = connectivityManager.activeNetworkInfo
            result["isConnected"] = networkInfo?.isConnected ?: false
            result["connectionType"] = networkInfo?.typeName ?: "Unknown"
            result["hasInternet"] = networkInfo?.isConnected ?: false
            result["hasValidated"] = networkInfo?.isConnected ?: false
        }

        Log.d(TAG, "Network Status: $result")
        return result
    }

    private fun getNetworkDiagnostics(): Map<String, Any> {
        val diagnostics = mutableMapOf<String, Any>()
        
        try {
            diagnostics["androidVersion"] = Build.VERSION.SDK_INT
            diagnostics["deviceModel"] = Build.MODEL
            diagnostics["manufacturer"] = Build.MANUFACTURER
            
            val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val network = connectivityManager.activeNetwork
                val capabilities = connectivityManager.getNetworkCapabilities(network)
                
                diagnostics["network"] = network?.toString() ?: "null"
                diagnostics["capabilities"] = buildMap {
                    put("internet", capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) ?: false)
                    put("validated", capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) ?: false)
                    put("notRestricted", capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED) ?: false)
                    put("notVpn", capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN) ?: false)
                    
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        put("notRoaming", capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_ROAMING) ?: false)
                        put("foreground", capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_FOREGROUND) ?: false)
                    }
                    
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        put("notCongested", capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_CONGESTED) ?: false)
                    }
                }
                
                diagnostics["transports"] = buildMap {
                    put("wifi", capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ?: false)
                    put("cellular", capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) ?: false)
                    put("ethernet", capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) ?: false)
                    put("bluetooth", capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH) ?: false)
                    put("vpn", capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) ?: false)
                }
                
                // Check if metered connection
                diagnostics["isMetered"] = connectivityManager.isActiveNetworkMetered
                
                // Check background data restrictions
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    diagnostics["restrictBackgroundStatus"] = when (connectivityManager.restrictBackgroundStatus) {
                        ConnectivityManager.RESTRICT_BACKGROUND_STATUS_DISABLED -> "Disabled"
                        ConnectivityManager.RESTRICT_BACKGROUND_STATUS_ENABLED -> "Enabled"
                        ConnectivityManager.RESTRICT_BACKGROUND_STATUS_WHITELISTED -> "Whitelisted"
                        else -> "Unknown"
                    }
                }
            }
            
            Log.d(TAG, "Network Diagnostics: $diagnostics")
        } catch (e: Exception) {
            Log.e(TAG, "Error getting network diagnostics", e)
            diagnostics["error"] = e.message ?: "Unknown error"
        }
        
        return diagnostics
    }

    private fun logNetworkState() {
        Log.d(TAG, "=== CaptainVFR Network State ===")
        Log.d(TAG, "Android Version: ${Build.VERSION.SDK_INT}")
        Log.d(TAG, "Device: ${Build.MANUFACTURER} ${Build.MODEL}")
        
        val status = checkNetworkStatus()
        Log.d(TAG, "Network Status: $status")
        
        val diagnostics = getNetworkDiagnostics()
        Log.d(TAG, "Network Diagnostics: $diagnostics")
        Log.d(TAG, "==============================")
    }
}