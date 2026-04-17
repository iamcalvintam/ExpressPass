package com.expresspass.expresspass.receivers

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Settings
import com.expresspass.expresspass.NotificationHelper
import com.expresspass.expresspass.services.AppMonitorService
import org.json.JSONArray
import java.io.File

class RevertSettingsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val settingsJson = loadSettingsJson(context)

        if (settingsJson == null || settingsJson == "[]") {
            // Dismiss the applied notification and show error
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.cancel(2001)
            NotificationHelper.showRevertFailed(context)
            context.stopService(Intent(context, AppMonitorService::class.java))
            return
        }

        val arr = JSONArray(settingsJson)
        var revertedCount = 0
        for (i in 0 until arr.length()) {
            val obj = arr.getJSONObject(i)
            if (obj.optInt("enabled", 1) == 1) {
                val type = obj.getString("setting_type")
                val key = obj.getString("setting_key")
                val valueOnRevert = obj.getString("value_on_revert")
                try {
                    when (type) {
                        "system" -> Settings.System.putString(context.contentResolver, key, valueOnRevert)
                        "secure" -> Settings.Secure.putString(context.contentResolver, key, valueOnRevert)
                        "global" -> Settings.Global.putString(context.contentResolver, key, valueOnRevert)
                    }
                    revertedCount++
                } catch (e: Exception) {
                    // Continue reverting other settings
                }
            }
        }

        // Dismiss the persistent "applied" notification
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.cancel(2001)

        NotificationHelper.showManualRevert(context, revertedCount)

        // Stop the monitoring service if it's running
        context.stopService(Intent(context, AppMonitorService::class.java))
    }

    private fun loadSettingsJson(context: Context): String? {
        // Try SharedPreferences first
        val prefs = context.getSharedPreferences("monitor", Context.MODE_PRIVATE)
        val fromPrefs = prefs.getString("settingsJson", null)
        if (!fromPrefs.isNullOrEmpty() && fromPrefs != "[]") {
            return fromPrefs
        }

        // Fallback to backup file
        return try {
            val file = File(context.filesDir, "settings_backup.json")
            if (file.exists()) file.readText() else null
        } catch (_: Exception) {
            null
        }
    }
}
