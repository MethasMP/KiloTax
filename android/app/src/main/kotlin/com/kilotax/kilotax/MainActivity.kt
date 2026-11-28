package com.kiloclaim.kiloclaim

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL_NAME = "kiloclaim/hardware_telemetry"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setTargetBluetoothName" -> {
                        val name = call.arguments as? String
                        NativeTelemetryStore.setTargetBluetoothTarget(this, name, null)
                        result.success(true)
                    }
                    "setTargetBluetoothTarget" -> {
                        val args = call.arguments as? Map<*, *>
                        val name = args?.get("name") as? String
                        val uuid = args?.get("uuid") as? String
                        NativeTelemetryStore.setTargetBluetoothTarget(this, name, uuid)
                        result.success(true)
                    }
                    "getCompletedNativeTrips" -> {
                        result.success(NativeTelemetryStore.getCompletedNativeTrips(this))
                    }
                    "acknowledgeNativeTripsIngested" -> {
                        val ids = (call.arguments as? List<*>)?.filterIsInstance<String>() ?: emptyList()
                        NativeTelemetryStore.acknowledgeNativeTripsIngested(this, ids)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
