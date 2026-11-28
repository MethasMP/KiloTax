package com.kiloclaim.kiloclaim

import android.Manifest
import android.bluetooth.BluetoothDevice
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.roundToInt

/**
 * Shared persistent store for Android native telemetry across MainActivity,
 * KiloClaimBluetoothReceiver, and KiloClaimTelemetryService.
 */
object NativeTelemetryStore {
    private const val PREFS_NAME = "kiloclaim_native_telemetry_prefs"
    private const val KEY_TARGET_BT_NAME = "kiloclaim_native_target_bt_name"
    private const val KEY_TARGET_BT_UUID = "kiloclaim_native_target_bt_uuid"
    private const val KEY_COMPLETED_TRIPS = "kiloclaim_native_completed_trips"

    fun setTargetBluetoothTarget(context: Context, name: String?, uuid: String?) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().apply {
            if (!name.isNullOrBlank()) {
                putString(KEY_TARGET_BT_NAME, name.lowercase().trim())
            } else {
                remove(KEY_TARGET_BT_NAME)
            }
            if (!uuid.isNullOrBlank()) {
                putString(KEY_TARGET_BT_UUID, uuid.lowercase().trim())
            } else {
                remove(KEY_TARGET_BT_UUID)
            }
            apply()
        }
    }

    fun hasTargetBluetoothConfigured(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val name = prefs.getString(KEY_TARGET_BT_NAME, null)
        val uuid = prefs.getString(KEY_TARGET_BT_UUID, null)
        return !name.isNullOrBlank() || !uuid.isNullOrBlank()
    }

    fun matchesTargetDevice(context: Context, device: BluetoothDevice): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val targetName = prefs.getString(KEY_TARGET_BT_NAME, null)
        val targetUuid = prefs.getString(KEY_TARGET_BT_UUID, null)
        if (targetName.isNullOrBlank() && targetUuid.isNullOrBlank()) return false

        val address = device.address?.lowercase()?.trim()
        if (!targetUuid.isNullOrBlank() && address == targetUuid) {
            return true
        }

        val deviceName = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED
            ) {
                null
            } else {
                device.name?.lowercase()?.trim()
            }
        } catch (_: SecurityException) {
            null
        }

        if (!targetName.isNullOrBlank()) {
            if (address == targetName) return true
            if (deviceName != null && (deviceName == targetName || deviceName.contains(targetName))) {
                return true
            }
        }
        return false
    }

    fun appendCompletedTrip(
        context: Context,
        distanceKm: Double,
        startedAtMs: Long,
        completedAtMs: Long,
        startLat: Double,
        startLng: Double,
        endLat: Double,
        endLng: Double,
        vehicleBluetoothMatched: Boolean
    ) {
        val tripJson = JSONObject().apply {
            put("id", "native_$completedAtMs")
            put("distanceKm", (distanceKm * 100.0).roundToInt() / 100.0)
            put("startedAt", startedAtMs)
            put("completedAt", completedAtMs)
            put("startLatitude", startLat)
            put("startLongitude", startLng)
            put("endLatitude", endLat)
            put("endLongitude", endLng)
            put("source", if (vehicleBluetoothMatched) "native_bluetooth_auto" else "native_motion_geofence")
            put("vehicleBluetoothMatched", vehicleBluetoothMatched)
        }

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_COMPLETED_TRIPS, "[]") ?: "[]"
        val arr = try {
            JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }
        arr.put(tripJson)
        prefs.edit().putString(KEY_COMPLETED_TRIPS, arr.toString()).apply()
    }

    fun getCompletedNativeTrips(context: Context): List<Map<String, Any>> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_COMPLETED_TRIPS, null) ?: return emptyList()
        val arr = try {
            JSONArray(raw)
        } catch (_: Exception) {
            return emptyList()
        }
        val list = mutableListOf<Map<String, Any>>()
        for (i in 0 until arr.length()) {
            val obj = arr.optJSONObject(i) ?: continue
            list.add(
                mapOf(
                    "id" to obj.optString("id"),
                    "distanceKm" to obj.optDouble("distanceKm", 0.0),
                    "startedAt" to obj.optLong("startedAt", 0L),
                    "completedAt" to obj.optLong("completedAt", 0L),
                    "startLatitude" to obj.optDouble("startLatitude", 0.0),
                    "startLongitude" to obj.optDouble("startLongitude", 0.0),
                    "endLatitude" to obj.optDouble("endLatitude", 0.0),
                    "endLongitude" to obj.optDouble("endLongitude", 0.0),
                    "source" to obj.optString("source", "native_bluetooth_auto"),
                    "vehicleBluetoothMatched" to obj.optBoolean("vehicleBluetoothMatched", true)
                )
            )
        }
        return list
    }

    fun acknowledgeNativeTripsIngested(context: Context, tripIds: List<String>) {
        if (tripIds.isEmpty()) return
        val idSet = tripIds.toSet()
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_COMPLETED_TRIPS, null) ?: return
        val arr = try {
            JSONArray(raw)
        } catch (_: Exception) {
            return
        }
        val remaining = JSONArray()
        for (i in 0 until arr.length()) {
            val obj = arr.optJSONObject(i) ?: continue
            if (!idSet.contains(obj.optString("id"))) {
                remaining.put(obj)
            }
        }
        prefs.edit().putString(KEY_COMPLETED_TRIPS, remaining.toString()).apply()
    }
}
