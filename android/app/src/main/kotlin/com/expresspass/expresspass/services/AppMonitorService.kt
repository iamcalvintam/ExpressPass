package com.expresspass.expresspass.services

import android.app.ActivityManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.provider.Settings
import com.expresspass.expresspass.NotificationHelper
import com.expresspass.expresspass.R
import com.expresspass.expresspass.receivers.RevertSettingsReceiver
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.*
import org.json.JSONArray

class AppMonitorService : Service() {

    companion object {
        const val CHANNEL_ID = "expresspass_monitor"
        const val NOTIFICATION_ID = 1001
        var isRunning = false
        var eventSink: EventChannel.EventSink? = null
    }

    private val serviceScope = CoroutineScope(Dispatchers.Default + Job())
    private var targetPackageName = ""
    private var settingsToRevert = mutableListOf<SettingEntry>()

    data class SettingEntry(
        val type: String,
        val key: String,
        val valueOnRevert: String
    )

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        targetPackageName = intent?.getStringExtra("packageName") ?: ""
        val settingsJson = intent?.getStringExtra("settingsJson") ?: "[]"
        parseSettings(settingsJson)

        // Save settings to shared prefs for the broadcast receiver
        getSharedPreferences("monitor", Context.MODE_PRIVATE).edit().apply {
            putString("settingsJson", settingsJson)
            apply()
        }

        val notification = buildNotification()
        startForeground(NOTIFICATION_ID, notification)
        isRunning = true

        startMonitoring()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        serviceScope.cancel()
        isRunning = false
        eventSink?.success(mapOf("event" to "stopped"))
    }

    private fun parseSettings(json: String) {
        settingsToRevert.clear()
        val arr = JSONArray(json)
        for (i in 0 until arr.length()) {
            val obj = arr.getJSONObject(i)
            if (obj.optInt("enabled", 1) == 1) {
                settingsToRevert.add(
                    SettingEntry(
                        type = obj.getString("setting_type"),
                        key = obj.getString("setting_key"),
                        valueOnRevert = obj.getString("value_on_revert")
                    )
                )
            }
        }
    }

    private fun startMonitoring() {
        serviceScope.launch {
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager

            while (isActive) {
                delay(2000)

                if (!isAppProcessRunning(activityManager, targetPackageName)) {
                    // Target app process was killed (swiped from recents / force stopped)
                    revertAllSettings()
                    NotificationHelper.showReverted(
                        this@AppMonitorService,
                        targetPackageName,
                        settingsToRevert.size
                    )
                    withContext(Dispatchers.Main) {
                        eventSink?.success(mapOf(
                            "event" to "reverted",
                            "packageName" to targetPackageName
                        ))
                    }
                    stopSelf()
                    return@launch
                }
            }
        }
    }

    private fun isAppProcessRunning(activityManager: ActivityManager, packageName: String): Boolean {
        val runningProcesses = activityManager.runningAppProcesses ?: return false
        return runningProcesses.any { it.processName == packageName || it.processName.startsWith("$packageName:") }
    }

    private fun revertAllSettings() {
        for (entry in settingsToRevert) {
            try {
                when (entry.type) {
                    "system" -> Settings.System.putString(contentResolver, entry.key, entry.valueOnRevert)
                    "secure" -> Settings.Secure.putString(contentResolver, entry.key, entry.valueOnRevert)
                    "global" -> Settings.Global.putString(contentResolver, entry.key, entry.valueOnRevert)
                }
            } catch (e: Exception) {
                // Log but continue reverting other settings
            }
        }
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "ExpressPass Monitor",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Monitors app usage to auto-revert settings"
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val revertIntent = Intent(this, RevertSettingsReceiver::class.java)
        val revertPendingIntent = PendingIntent.getBroadcast(
            this, 0, revertIntent, PendingIntent.FLAG_IMMUTABLE
        )

        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("ExpressPass Active")
            .setContentText("Monitoring $targetPackageName — settings will auto-revert")
            .setSmallIcon(R.drawable.ic_notification)
            .addAction(
                Notification.Action.Builder(
                    null, "Revert Now", revertPendingIntent
                ).build()
            )
            .setOngoing(true)
            .build()
    }
}
