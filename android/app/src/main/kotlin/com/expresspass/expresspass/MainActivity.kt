package com.expresspass.expresspass

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import com.expresspass.expresspass.channels.SettingsChannelHandler
import com.expresspass.expresspass.channels.PackageManagerHandler
import com.expresspass.expresspass.channels.PermissionHandler
import com.expresspass.expresspass.channels.ShortcutHandler
import com.expresspass.expresspass.services.AppMonitorService
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle

class MainActivity : FlutterActivity() {

    private lateinit var settingsHandler: SettingsChannelHandler
    private lateinit var packageManagerHandler: PackageManagerHandler
    private lateinit var permissionHandler: PermissionHandler
    private lateinit var shortcutHandler: ShortcutHandler
    private var pendingDeepLinkPackage: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        settingsHandler = SettingsChannelHandler(this)
        packageManagerHandler = PackageManagerHandler(this)
        permissionHandler = PermissionHandler(this)
        shortcutHandler = ShortcutHandler(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.expresspass/settings")
            .setMethodCallHandler(settingsHandler)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.expresspass/packages")
            .setMethodCallHandler(packageManagerHandler)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.expresspass/permissions")
            .setMethodCallHandler(permissionHandler)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.expresspass/shortcuts")
            .setMethodCallHandler(shortcutHandler)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.expresspass/notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showApplied" -> {
                        val appLabel = call.argument<String>("appLabel") ?: ""
                        val count = call.argument<Int>("count") ?: 0
                        NotificationHelper.showApplied(this, appLabel, count)
                        result.success(true)
                    }
                    "showReverted" -> {
                        val appLabel = call.argument<String>("appLabel") ?: ""
                        val count = call.argument<Int>("count") ?: 0
                        NotificationHelper.showReverted(this, appLabel, count)
                        result.success(true)
                    }
                    "showManualRevert" -> {
                        val count = call.argument<Int>("count") ?: 0
                        NotificationHelper.showManualRevert(this, count)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.expresspass/service")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startMonitoring" -> {
                        val packageName = call.argument<String>("packageName") ?: ""
                        val settingsJson = call.argument<String>("settingsJson") ?: "[]"
                        val intent = Intent(this, AppMonitorService::class.java).apply {
                            putExtra("packageName", packageName)
                            putExtra("settingsJson", settingsJson)
                        }
                        startForegroundService(intent)
                        result.success(true)
                    }
                    "stopMonitoring" -> {
                        stopService(Intent(this, AppMonitorService::class.java))
                        result.success(true)
                    }
                    "isRunning" -> {
                        result.success(AppMonitorService.isRunning)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.expresspass/deeplink")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialLink" -> {
                        val link = consumeInitialDeepLink()
                        result.success(link)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.expresspass/usage_events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    AppMonitorService.eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    AppMonitorService.eventSink = null
                }
            })
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Handle cold-start deep link
        handleDeepLink(intent)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PermissionHandler.NOTIFICATION_PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            PermissionHandler.pendingResult?.success(granted)
            PermissionHandler.pendingResult = null
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleDeepLink(intent)
    }

    private fun handleDeepLink(intent: Intent) {
        var packageName: String? = null

        // Check for URI deep link (expresspass://launch/...)
        val data = intent.data
        if (data?.scheme == "expresspass" && data.host == "launch") {
            packageName = data.pathSegments.firstOrNull()
        }

        // Check for shortcut extra (launch_package)
        if (packageName == null) {
            packageName = intent.getStringExtra("launch_package")
        }

        if (packageName != null) {
            pendingDeepLinkPackage = packageName
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, "com.expresspass/deeplink")
                    .invokeMethod("launch", packageName)
            }
        }
    }

    private fun consumeInitialDeepLink(): String? {
        val link = pendingDeepLinkPackage
        pendingDeepLinkPackage = null
        return link
    }
}
