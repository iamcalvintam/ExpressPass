package com.expresspass.expresspass

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context

object NotificationHelper {

    const val STATUS_CHANNEL_ID = "expresspass_status"
    private const val APPLY_NOTIFICATION_ID = 2001
    private const val REVERT_NOTIFICATION_ID = 2002

    fun createStatusChannel(context: Context) {
        val channel = NotificationChannel(
            STATUS_CHANNEL_ID,
            "ExpressPass Status",
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = "Notifications when settings are applied or reverted"
        }
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    fun showApplied(context: Context, appLabel: String, settingCount: Int) {
        createStatusChannel(context)
        val notification = Notification.Builder(context, STATUS_CHANNEL_ID)
            .setContentTitle("Settings Applied")
            .setContentText("$settingCount setting(s) modified for $appLabel")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setAutoCancel(true)
            .setStyle(Notification.BigTextStyle()
                .bigText("$settingCount setting(s) temporarily modified before launching $appLabel. They will be reverted when you leave the app."))
            .build()

        val manager = context.getSystemService(NotificationManager::class.java)
        manager.notify(APPLY_NOTIFICATION_ID, notification)
    }

    fun showReverted(context: Context, appLabel: String, settingCount: Int) {
        createStatusChannel(context)
        val notification = Notification.Builder(context, STATUS_CHANNEL_ID)
            .setContentTitle("Settings Reverted")
            .setContentText("$settingCount setting(s) restored after leaving $appLabel")
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setAutoCancel(true)
            .build()

        val manager = context.getSystemService(NotificationManager::class.java)
        manager.notify(REVERT_NOTIFICATION_ID, notification)
    }

    fun showManualRevert(context: Context, settingCount: Int) {
        createStatusChannel(context)
        val notification = Notification.Builder(context, STATUS_CHANNEL_ID)
            .setContentTitle("Settings Reverted")
            .setContentText("$settingCount setting(s) manually reverted")
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setAutoCancel(true)
            .build()

        val manager = context.getSystemService(NotificationManager::class.java)
        manager.notify(REVERT_NOTIFICATION_ID, notification)
    }
}
