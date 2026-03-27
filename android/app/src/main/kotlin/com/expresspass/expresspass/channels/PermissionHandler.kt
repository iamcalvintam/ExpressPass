package com.expresspass.expresspass.channels

import android.app.Activity
import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import androidx.core.app.ActivityCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class PermissionHandler(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val NOTIFICATION_PERMISSION_REQUEST_CODE = 1001
        var pendingResult: MethodChannel.Result? = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasWriteSecureSettings" -> {
                result.success(checkWriteSecureSettings())
            }
            "hasUsageStatsPermission" -> {
                result.success(checkUsageStatsPermission())
            }
            "requestUsageStatsPermission" -> {
                val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                result.success(true)
            }
            "hasNotificationPermission" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    val granted = context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
                        android.content.pm.PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                } else {
                    result.success(true)
                }
            }
            "requestNotificationPermission" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    val activity = context as? Activity
                    if (activity != null) {
                        val granted = context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
                            android.content.pm.PackageManager.PERMISSION_GRANTED
                        if (granted) {
                            result.success(true)
                        } else {
                            pendingResult = result
                            ActivityCompat.requestPermissions(
                                activity,
                                arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                                NOTIFICATION_PERMISSION_REQUEST_CODE
                            )
                        }
                    } else {
                        result.success(false)
                    }
                } else {
                    result.success(true)
                }
            }
            "openNotificationSettings" -> {
                val intent = Intent().apply {
                    action = Settings.ACTION_APP_NOTIFICATION_SETTINGS
                    putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                result.success(true)
            }
            "getAdbCommand" -> {
                result.success("adb shell pm grant ${context.packageName} android.permission.WRITE_SECURE_SETTINGS")
            }
            else -> result.notImplemented()
        }
    }

    private fun checkWriteSecureSettings(): Boolean {
        return try {
            // Try to read a known secure setting to verify permission
            val testValue = Settings.Secure.getString(context.contentResolver, "development_settings_enabled")
            // Try a write operation with the same value to test write permission
            if (testValue != null) {
                Settings.Secure.putString(context.contentResolver, "development_settings_enabled", testValue)
            } else {
                Settings.Global.getString(context.contentResolver, "development_settings_enabled") != null
            }
            true
        } catch (e: SecurityException) {
            false
        }
    }

    private fun checkUsageStatsPermission(): Boolean {
        val appOpsManager = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOpsManager.unsafeCheckOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            context.packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }
}
