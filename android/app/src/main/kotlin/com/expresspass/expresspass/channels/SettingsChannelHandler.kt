package com.expresspass.expresspass.channels

import android.content.Context
import android.provider.Settings
import android.database.Cursor
import android.net.Uri
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SettingsChannelHandler(private val context: Context) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "writeSetting" -> {
                val type = call.argument<String>("type") ?: ""
                val key = call.argument<String>("key") ?: ""
                val value = call.argument<String>("value") ?: ""
                try {
                    val success = writeSetting(type, key, value)
                    result.success(success)
                } catch (e: SecurityException) {
                    result.error("PERMISSION_DENIED", "WRITE_SECURE_SETTINGS not granted", e.message)
                } catch (e: Exception) {
                    result.error("WRITE_ERROR", "Failed to write setting", e.message)
                }
            }
            "readSetting" -> {
                val type = call.argument<String>("type") ?: ""
                val key = call.argument<String>("key") ?: ""
                try {
                    val value = readSetting(type, key)
                    result.success(value)
                } catch (e: Exception) {
                    result.error("READ_ERROR", "Failed to read setting", e.message)
                }
            }
            "getSettingsList" -> {
                val type = call.argument<String>("type") ?: ""
                try {
                    val settings = getSettingsList(type)
                    result.success(settings)
                } catch (e: Exception) {
                    result.error("LIST_ERROR", "Failed to list settings", e.message)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun writeSetting(type: String, key: String, value: String): Boolean {
        return when (type) {
            "system" -> Settings.System.putString(context.contentResolver, key, value)
            "secure" -> Settings.Secure.putString(context.contentResolver, key, value)
            "global" -> Settings.Global.putString(context.contentResolver, key, value)
            else -> false
        }
    }

    private fun readSetting(type: String, key: String): String? {
        return when (type) {
            "system" -> Settings.System.getString(context.contentResolver, key)
            "secure" -> Settings.Secure.getString(context.contentResolver, key)
            "global" -> Settings.Global.getString(context.contentResolver, key)
            else -> null
        }
    }

    private fun getSettingsList(type: String): List<Map<String, String?>> {
        val uri: Uri = when (type) {
            "system" -> Settings.System.CONTENT_URI
            "secure" -> Settings.Secure.CONTENT_URI
            "global" -> Settings.Global.CONTENT_URI
            else -> return emptyList()
        }

        val settings = mutableListOf<Map<String, String?>>()
        var cursor: Cursor? = null
        try {
            cursor = context.contentResolver.query(uri, arrayOf("name", "value"), null, null, null)
            cursor?.let {
                while (it.moveToNext()) {
                    val name = it.getString(0)
                    val value = it.getString(1)
                    settings.add(mapOf("name" to name, "value" to value))
                }
            }
        } finally {
            cursor?.close()
        }
        return settings
    }
}
