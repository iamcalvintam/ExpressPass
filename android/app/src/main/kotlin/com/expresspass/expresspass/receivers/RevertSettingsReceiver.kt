package com.expresspass.expresspass.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Settings
import com.expresspass.expresspass.NotificationHelper
import com.expresspass.expresspass.services.AppMonitorService
import org.json.JSONArray

class RevertSettingsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val prefs = context.getSharedPreferences("monitor", Context.MODE_PRIVATE)
        val settingsJson = prefs.getString("settingsJson", "[]") ?: "[]"

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

        NotificationHelper.showManualRevert(context, revertedCount)

        // Stop the monitoring service
        context.stopService(Intent(context, AppMonitorService::class.java))
    }
}
