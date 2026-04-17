package com.expresspass.expresspass.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
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
import java.io.File

class AppMonitorService : Service() {

    companion object {
        const val CHANNEL_ID = "expresspass_monitor"
        const val NOTIFICATION_ID = 1001
        const val DEFAULT_TIMEOUT_MS = 4 * 60 * 60 * 1000L // 4 hours
        const val POLL_INTERVAL_MS = 2000L
        const val GRACE_POLLS_REQUIRED = 3 // 3 consecutive "away" polls (~6s) before reverting
        var isRunning = false
        var eventSink: EventChannel.EventSink? = null
    }

    private val serviceScope = CoroutineScope(Dispatchers.Default + Job())
    private var targetPackageName = ""
    private var settingsToRevert = mutableListOf<SettingEntry>()
    private var startTimeMillis = 0L
    private var timeoutMs = DEFAULT_TIMEOUT_MS

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
        timeoutMs = intent?.getLongExtra("timeoutMs", DEFAULT_TIMEOUT_MS) ?: DEFAULT_TIMEOUT_MS
        parseSettings(settingsJson)

        // Save settings to shared prefs for the broadcast receiver
        getSharedPreferences("monitor", Context.MODE_PRIVATE).edit().apply {
            putString("settingsJson", settingsJson)
            apply()
        }

        // Write backup file as fallback
        try {
            File(filesDir, "settings_backup.json").writeText(settingsJson)
        } catch (_: Exception) {}

        val notification = buildNotification()
        startForeground(NOTIFICATION_ID, notification)
        isRunning = true
        startTimeMillis = System.currentTimeMillis()

        startMonitoring()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        serviceScope.cancel()
        isRunning = false
        try {
            eventSink?.success(mapOf("event" to "stopped"))
        } catch (_: Exception) {
            eventSink = null
        }
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
            var awayCount = 0

            while (isActive) {
                delay(POLL_INTERVAL_MS)

                // Check timeout
                val elapsed = System.currentTimeMillis() - startTimeMillis
                if (elapsed >= timeoutMs) {
                    revertAllSettings()
                    NotificationHelper.showTimedOut(
                        this@AppMonitorService,
                        targetPackageName,
                        settingsToRevert.size
                    )
                    emitEvent("timedOut")
                    stopSelf()
                    return@launch
                }

                // Check if target app is still in foreground using UsageStatsManager
                if (isTargetAppForeground()) {
                    awayCount = 0
                } else {
                    awayCount++
                    if (awayCount >= GRACE_POLLS_REQUIRED) {
                        revertAllSettings()
                        NotificationHelper.showReverted(
                            this@AppMonitorService,
                            targetPackageName,
                            settingsToRevert.size
                        )
                        emitEvent("reverted")
                        stopSelf()
                        return@launch
                    }
                }
            }
        }
    }

    private fun isTargetAppForeground(): Boolean {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return true // Fail-safe: assume still running if we can't check

        val now = System.currentTimeMillis()
        val events = usageStatsManager.queryEvents(now - 5000, now)
        val event = UsageEvents.Event()

        var lastForegroundPackage: String? = null

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                lastForegroundPackage = event.packageName
            }
        }

        // If no foreground event found in the window, assume target is still in front
        if (lastForegroundPackage == null) return true

        // Check if the foreground app is our target or our own app
        return lastForegroundPackage == targetPackageName ||
                lastForegroundPackage == packageName
    }

    private suspend fun emitEvent(eventName: String) {
        withContext(Dispatchers.Main) {
            try {
                eventSink?.success(mapOf(
                    "event" to eventName,
                    "packageName" to targetPackageName
                ))
            } catch (_: Exception) {
                eventSink = null
            }
        }
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
