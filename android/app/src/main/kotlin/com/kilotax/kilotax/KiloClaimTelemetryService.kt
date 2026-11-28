package com.kiloclaim.kiloclaim

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Foreground service that owns Android active-drive GPS recording independently
 * of MainActivity so tracking survives app swipe-kill and stops GPS when parked.
 */
class KiloClaimTelemetryService : Service() {
    companion object {
        const val ACTION_START_DRIVE = "com.kiloclaim.action.START_DRIVE"
        const val ACTION_SCHEDULE_STOP = "com.kiloclaim.action.SCHEDULE_STOP"
        const val EXTRA_BLUETOOTH_MATCHED = "extra_bluetooth_matched"

        private const val CHANNEL_ID = "kiloclaim_trip_tracking"
        private const val NOTIFICATION_ID = 4102
        private const val DISCONNECT_GRACE_MS = 180_000L
        private const val STATIONARY_AUTO_STOP_MS = 240_000L
    }

    private enum class PowerState {
        DEEP_SLEEP,
        ACTIVE_DRIVING,
        DISCONNECT_GRACE
    }

    private val handler = Handler(Looper.getMainLooper())
    private var locationManager: LocationManager? = null
    private var powerState = PowerState.DEEP_SLEEP
    private var vehicleBluetoothMatched = false

    private var startLocation: Location? = null
    private var lastLocation: Location? = null
    private var stationarySinceMs: Long? = null
    private var accumulatedDistanceMeters = 0.0
    private var tripStartTimeMs = 0L

    private val disconnectGraceRunnable = Runnable {
        if (powerState == PowerState.DISCONNECT_GRACE) {
            finalizeAndStop()
        }
    }

    private val locationListener = object : LocationListener {
        override fun onLocationChanged(location: Location) {
            if (powerState == PowerState.DEEP_SLEEP) return
            if (location.hasAccuracy() && location.accuracy > 65f) return

            if (startLocation == null) {
                startLocation = location
                lastLocation = location
                return
            }

            val prev = lastLocation ?: return
            val delta = location.distanceTo(prev).toDouble()
            if (delta > 3.0 && delta < 2000.0) {
                accumulatedDistanceMeters += delta
                lastLocation = location
                stationarySinceMs = null
                if (powerState == PowerState.DISCONNECT_GRACE && location.speed >= 4.0f) {
                    handler.removeCallbacks(disconnectGraceRunnable)
                    powerState = PowerState.ACTIVE_DRIVING
                }
            } else if (!vehicleBluetoothMatched && location.speed < 0.8f) {
                val now = System.currentTimeMillis()
                val since = stationarySinceMs ?: now.also { stationarySinceMs = it }
                if (now - since >= STATIONARY_AUTO_STOP_MS) {
                    finalizeAndStop()
                }
            }
        }

        @Deprecated("Deprecated in Java")
        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
        override fun onProviderEnabled(provider: String) {}
        override fun onProviderDisabled(provider: String) {}
    }

    override fun onCreate() {
        super.onCreate()
        locationManager = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        ensureNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_DRIVE -> {
                val btMatched = intent.getBooleanExtra(EXTRA_BLUETOOTH_MATCHED, false)
                handler.removeCallbacks(disconnectGraceRunnable)
                if (powerState == PowerState.DEEP_SLEEP) {
                    startForegroundRecording(btMatched)
                } else {
                    vehicleBluetoothMatched = vehicleBluetoothMatched || btMatched
                    powerState = PowerState.ACTIVE_DRIVING
                }
            }
            ACTION_SCHEDULE_STOP -> {
                if (powerState == PowerState.ACTIVE_DRIVING) {
                    powerState = PowerState.DISCONNECT_GRACE
                    handler.removeCallbacks(disconnectGraceRunnable)
                    handler.postDelayed(disconnectGraceRunnable, DISCONNECT_GRACE_MS)
                }
            }
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        handler.removeCallbacks(disconnectGraceRunnable)
        stopGpsUpdates()
        super.onDestroy()
    }

    private fun startForegroundRecording(btMatched: Boolean) {
        val hasFine = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        val hasCoarse = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        if (!hasFine && !hasCoarse) {
            stopSelf()
            return
        }

        val notification = buildTrackingNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val serviceType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            } else {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            }
            startForeground(NOTIFICATION_ID, notification, serviceType)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        powerState = PowerState.ACTIVE_DRIVING
        vehicleBluetoothMatched = btMatched
        startLocation = null
        lastLocation = null
        stationarySinceMs = null
        accumulatedDistanceMeters = 0.0
        tripStartTimeMs = System.currentTimeMillis()

        try {
            locationManager?.requestLocationUpdates(
                LocationManager.GPS_PROVIDER,
                3000L,
                10f,
                locationListener,
                Looper.getMainLooper()
            )
        } catch (_: SecurityException) {
            finalizeAndStop()
        } catch (_: IllegalArgumentException) {
            finalizeAndStop()
        }
    }

    private fun finalizeAndStop() {
        handler.removeCallbacks(disconnectGraceRunnable)
        stopGpsUpdates()

        val wasActive = powerState != PowerState.DEEP_SLEEP
        powerState = PowerState.DEEP_SLEEP

        if (wasActive) {
            val distanceKm = accumulatedDistanceMeters / 1000.0
            if (distanceKm >= 0.1) {
                NativeTelemetryStore.appendCompletedTrip(
                    context = this,
                    distanceKm = distanceKm,
                    startedAtMs = tripStartTimeMs,
                    completedAtMs = System.currentTimeMillis(),
                    startLat = startLocation?.latitude ?: 0.0,
                    startLng = startLocation?.longitude ?: 0.0,
                    endLat = lastLocation?.latitude ?: 0.0,
                    endLng = lastLocation?.longitude ?: 0.0,
                    vehicleBluetoothMatched = vehicleBluetoothMatched
                )
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun stopGpsUpdates() {
        try {
            locationManager?.removeUpdates(locationListener)
        } catch (_: SecurityException) {
        }
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                "KiloClaim Trip Tracking",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Active while your vehicle is driving to log ATO-compliant mileage."
                setShowBadge(false)
            }
            manager?.createNotificationChannel(channel)
        }
    }

    private fun buildTrackingNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("KiloClaim Auto-Tracking")
            .setContentText("Recording drive in background (GPS sleeps when parked)")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}
