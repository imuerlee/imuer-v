package com.nebula.nebula_vpn

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.i(TAG, "Boot completed, checking auto-start preference")
            
            val prefs: SharedPreferences = context.getSharedPreferences(
                "nebula_vpn_prefs",
                Context.MODE_PRIVATE
            )
            
            val autoStartEnabled = prefs.getBoolean("auto_start", false)
            
            if (autoStartEnabled) {
                Log.i(TAG, "Auto-start enabled, launching app")
                launchApp(context)
            }
        }
    }

    private fun launchApp(context: Context) {
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            putExtra("auto_connect", true)
        }
        context.startActivity(launchIntent)
    }
}
