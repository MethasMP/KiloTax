package com.kiloclaim.kiloclaim

import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.content.ContextCompat

/**
 * Manifest-registered receiver that survives Activity termination and wakes
 * KiloClaimTelemetryService whenever the paired vehicle Bluetooth connects.
 */
class KiloClaimBluetoothReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        val ctx = context ?: return
        val action = intent?.action ?: return

        if (action == Intent.ACTION_BOOT_COMPLETED) {
            // Keep GPS off after boot; receiver stays armed for next vehicle Bluetooth connect.
            return
        }

        if (action != BluetoothDevice.ACTION_ACL_CONNECTED &&
            action != BluetoothDevice.ACTION_ACL_DISCONNECTED
        ) {
            return
        }

        val device: BluetoothDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
        }
        device ?: return

        if (!NativeTelemetryStore.matchesTargetDevice(ctx, device)) return

        val serviceIntent = Intent(ctx, KiloClaimTelemetryService::class.java).apply {
            if (action == BluetoothDevice.ACTION_ACL_CONNECTED) {
                this.action = KiloClaimTelemetryService.ACTION_START_DRIVE
                putExtra(KiloClaimTelemetryService.EXTRA_BLUETOOTH_MATCHED, true)
            } else {
                this.action = KiloClaimTelemetryService.ACTION_SCHEDULE_STOP
            }
        }

        try {
            if (action == BluetoothDevice.ACTION_ACL_CONNECTED) {
                ContextCompat.startForegroundService(ctx, serviceIntent)
            } else {
                ctx.startService(serviceIntent)
            }
        } catch (_: IllegalStateException) {
            // Android 12+ background foreground-service restriction guard.
        }
    }
}
