package com.expresspass.expresspass.channels

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.AdaptiveIconDrawable
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class PackageManagerHandler(private val context: Context) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInstalledApps" -> {
                try {
                    val apps = getInstalledApps()
                    result.success(apps)
                } catch (e: Exception) {
                    result.error("LIST_ERROR", "Failed to list apps", e.message)
                }
            }
            "launchApp" -> {
                val packageName = call.argument<String>("packageName") ?: ""
                try {
                    launchApp(packageName)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("LAUNCH_ERROR", "Failed to launch app", e.message)
                }
            }
            "getAppIcon" -> {
                val packageName = call.argument<String>("packageName") ?: ""
                try {
                    val icon = getAppIcon(packageName)
                    result.success(icon)
                } catch (e: Exception) {
                    result.error("ICON_ERROR", "Failed to get icon", e.message)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun getInstalledApps(): List<Map<String, Any?>> {
        val pm = context.packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolveInfos = pm.queryIntentActivities(intent, 0)

        return resolveInfos.mapNotNull { resolveInfo ->
            val appInfo = resolveInfo.activityInfo.applicationInfo
            val packageName = appInfo.packageName

            // Skip our own app
            if (packageName == context.packageName) return@mapNotNull null

            val label = pm.getApplicationLabel(appInfo).toString()
            // Use resolveInfo.loadIcon which respects activity-specific and adaptive icons
            val iconDrawable = resolveInfo.loadIcon(pm)
            val iconBytes = drawableToBytes(iconDrawable)

            mapOf(
                "packageName" to packageName,
                "label" to label,
                "icon" to iconBytes
            )
        }.sortedBy { (it["label"] as String).lowercase() }
    }

    private fun launchApp(packageName: String) {
        val intent = context.packageManager.getLaunchIntentForPackage(packageName)
            ?: throw Exception("Cannot launch $packageName")
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    private fun getAppIcon(packageName: String): ByteArray? {
        return try {
            val drawable = context.packageManager.getApplicationIcon(packageName)
            drawableToBytes(drawable)
        } catch (e: PackageManager.NameNotFoundException) {
            null
        }
    }

    private fun drawableToBytes(drawable: Drawable): ByteArray {
        val size = 192 // render at a consistent high-res size
        val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
            // Scale up small bitmaps
            val src = drawable.bitmap
            if (src.width >= size) src
            else Bitmap.createScaledBitmap(src, size, size, true)
        } else {
            // Handles AdaptiveIconDrawable, VectorDrawable, LayerDrawable, etc.
            val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            drawable.setBounds(0, 0, size, size)
            drawable.draw(canvas)
            bmp
        }
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 90, stream)
        return stream.toByteArray()
    }
}
