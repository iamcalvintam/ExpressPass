package com.expresspass.expresspass

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.os.Bundle
import android.provider.Settings
import com.expresspass.expresspass.services.AppMonitorService
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * Lightweight native activity that handles shortcut launches without booting the Flutter engine.
 * Reads settings from SQLite directly, applies them, launches the target app, and finishes.
 */
class ShortcutLaunchActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val packageName = extractPackageName(intent)
        if (packageName == null) {
            // Not a valid shortcut — hand off to Flutter main activity
            startActivity(Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            })
            finishAndRemoveTask()
            return
        }

        handleShortcutLaunch(packageName)
    }

    private fun extractPackageName(intent: Intent): String? {
        // Check URI deep link (expresspass://launch/...)
        val data = intent.data
        if (data?.scheme == "expresspass" && data.host == "launch") {
            return data.pathSegments.firstOrNull()
        }
        // Check shortcut extra
        return intent.getStringExtra("launch_package")
    }

    private fun handleShortcutLaunch(targetPackage: String) {
        // Read settings from the SQLite database directly
        val dbPath = getDatabasePath("expresspass.db").absolutePath
        val dbFile = File(dbPath)
        if (!dbFile.exists()) {
            finishAndRemoveTask()
            return
        }

        val db = SQLiteDatabase.openDatabase(dbPath, null, SQLiteDatabase.OPEN_READONLY)
        val settings = mutableListOf<SettingRow>()

        try {
            val cursor = db.rawQuery(
                "SELECT setting_type, label, setting_key, value_on_launch, value_on_revert FROM app_settings WHERE package_name = ? AND enabled = 1",
                arrayOf(targetPackage)
            )
            while (cursor.moveToNext()) {
                settings.add(SettingRow(
                    type = cursor.getString(0),
                    label = cursor.getString(1),
                    key = cursor.getString(2),
                    valueOnLaunch = cursor.getString(3),
                    valueOnRevert = cursor.getString(4),
                ))
            }
            cursor.close()
        } finally {
            db.close()
        }

        if (settings.isEmpty()) {
            finishAndRemoveTask()
            return
        }

        // Apply settings
        for (setting in settings) {
            try {
                when (setting.type) {
                    "system" -> Settings.System.putString(contentResolver, setting.key, setting.valueOnLaunch)
                    "secure" -> Settings.Secure.putString(contentResolver, setting.key, setting.valueOnLaunch)
                    "global" -> Settings.Global.putString(contentResolver, setting.key, setting.valueOnLaunch)
                }
            } catch (_: Exception) {}
        }

        // Build settings JSON for the monitoring service / revert receiver
        val settingsJson = buildSettingsJson(settings)

        // Save to SharedPreferences and backup file for RevertSettingsReceiver
        getSharedPreferences("monitor", Context.MODE_PRIVATE).edit().apply {
            putString("settingsJson", settingsJson)
            apply()
        }
        try {
            File(filesDir, "settings_backup.json").writeText(settingsJson)
        } catch (_: Exception) {}

        // Check auto-revert preference
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val autoRevert = prefs.getBoolean("flutter.auto_revert_$targetPackage", true)

        // Show notification
        NotificationHelper.showApplied(this, targetPackage, settings.size, autoRevert)

        // Start monitoring service if auto-revert is on
        if (autoRevert) {
            val serviceIntent = Intent(this, AppMonitorService::class.java).apply {
                putExtra("packageName", targetPackage)
                putExtra("settingsJson", settingsJson)
                putExtra("timeoutMs", AppMonitorService.DEFAULT_TIMEOUT_MS)
            }
            startForegroundService(serviceIntent)
        }

        // Track active session in SharedPreferences
        trackActiveSession(prefs, targetPackage, settings.size)

        // Launch target app
        val launchIntent = packageManager.getLaunchIntentForPackage(targetPackage)
        if (launchIntent != null) {
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(launchIntent)
        }

        // Done — remove from recents
        finishAndRemoveTask()
    }

    private fun buildSettingsJson(settings: List<SettingRow>): String {
        val arr = JSONArray()
        for (s in settings) {
            arr.put(JSONObject().apply {
                put("enabled", 1)
                put("setting_type", s.type)
                put("setting_key", s.key)
                put("value_on_revert", s.valueOnRevert)
                put("value_on_launch", s.valueOnLaunch)
                put("label", s.label)
                put("package_name", "")
            })
        }
        return arr.toString()
    }

    private fun trackActiveSession(prefs: android.content.SharedPreferences, packageName: String, count: Int) {
        try {
            val existing = prefs.getString("flutter.active_sessions", null)
            val sessions = if (existing != null) JSONArray(existing) else JSONArray()

            // Remove existing session for this package
            val filtered = JSONArray()
            for (i in 0 until sessions.length()) {
                val obj = sessions.getJSONObject(i)
                if (obj.getString("packageName") != packageName) {
                    filtered.put(obj)
                }
            }

            // Add new session
            filtered.put(JSONObject().apply {
                put("packageName", packageName)
                put("appLabel", packageName)
                put("settingsCount", count)
                put("appliedAt", java.time.Instant.now().toString())
            })

            prefs.edit().putString("flutter.active_sessions", filtered.toString()).apply()
        } catch (_: Exception) {}
    }

    private data class SettingRow(
        val type: String,
        val label: String,
        val key: String,
        val valueOnLaunch: String,
        val valueOnRevert: String,
    )
}
