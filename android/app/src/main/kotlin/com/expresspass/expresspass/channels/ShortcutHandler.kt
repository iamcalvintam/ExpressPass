package com.expresspass.expresspass.channels

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.drawable.Icon
import android.net.Uri
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class ShortcutHandler(private val context: Context) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestPinShortcut" -> {
                val packageName = call.argument<String>("packageName") ?: ""
                val label = call.argument<String>("label") ?: ""
                val iconBytes = call.argument<ByteArray>("icon")
                try {
                    val success = requestPinShortcut(packageName, label, iconBytes)
                    result.success(success)
                } catch (e: Exception) {
                    result.error("SHORTCUT_ERROR", "Failed: ${e.message}", null)
                }
            }
            "isSupported" -> {
                val sm = context.getSystemService(ShortcutManager::class.java)
                result.success(sm.isRequestPinShortcutSupported)
            }
            else -> result.notImplemented()
        }
    }

    private fun requestPinShortcut(packageName: String, label: String, iconBytes: ByteArray?): Boolean {
        val shortcutIntent = Intent(Intent.ACTION_VIEW).apply {
            data = Uri.parse("expresspass://launch/$packageName")
            component = ComponentName(context.packageName, "${context.packageName}.MainActivity")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }

        val bitmap = if (iconBytes != null) {
            BitmapFactory.decodeByteArray(iconBytes, 0, iconBytes.size)
        } else null

        val scaledBitmap = if (bitmap != null) {
            Bitmap.createScaledBitmap(bitmap, 192, 192, true)
        } else {
            val bmp = Bitmap.createBitmap(192, 192, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            val paint = Paint().apply { color = 0xFFF59E0B.toInt() }
            canvas.drawCircle(96f, 96f, 96f, paint)
            val textPaint = Paint().apply {
                color = 0xFFFFFFFF.toInt()
                textSize = 80f
                textAlign = Paint.Align.CENTER
            }
            canvas.drawText("E", 96f, 120f, textPaint)
            bmp
        }

        val sm = context.getSystemService(ShortcutManager::class.java)
        if (sm.isRequestPinShortcutSupported) {
            val shortcutId = "ep_${System.currentTimeMillis()}"

            val shortcutInfo = ShortcutInfo.Builder(context, shortcutId)
                .setShortLabel(label)
                .setLongLabel("$label via ExpressPass")
                .setIcon(Icon.createWithAdaptiveBitmap(scaledBitmap))
                .setIntent(shortcutIntent)
                .build()

            val pinResult = sm.requestPinShortcut(shortcutInfo, null)
            if (pinResult) return true
        }

        // Fallback: legacy broadcast
        val legacyIntent = Intent("com.android.launcher.action.INSTALL_SHORTCUT").apply {
            putExtra(Intent.EXTRA_SHORTCUT_INTENT, shortcutIntent)
            putExtra(Intent.EXTRA_SHORTCUT_NAME, label)
            putExtra("duplicate", false)
            putExtra(Intent.EXTRA_SHORTCUT_ICON, scaledBitmap)
        }
        context.sendBroadcast(legacyIntent)

        return true
    }
}
