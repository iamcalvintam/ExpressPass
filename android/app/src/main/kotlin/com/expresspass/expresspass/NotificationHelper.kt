package com.expresspass.expresspass

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import com.expresspass.expresspass.receivers.RevertSettingsReceiver

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

    fun showApplied(context: Context, appLabel: String, settingCount: Int, autoRevert: Boolean) {
        createStatusChannel(context)

        val builder = Notification.Builder(context, STATUS_CHANNEL_ID)
            .setContentTitle("Settings Applied")
            .setContentText("$settingCount setting(s) modified for $appLabel")
            .setSmallIcon(R.drawable.ic_notification)

        if (autoRevert) {
            builder
                .setAutoCancel(true)
                .setStyle(Notification.BigTextStyle()
                    .bigText("$settingCount setting(s) temporarily modified before launching $appLabel. They will be reverted when you leave the app."))
        } else {
            val revertIntent = Intent(context, RevertSettingsReceiver::class.java)
            val revertPendingIntent = PendingIntent.getBroadcast(
                context, 0, revertIntent, PendingIntent.FLAG_IMMUTABLE
            )

            builder
                .setOngoing(true)
                .setAutoCancel(false)
                .setStyle(Notification.BigTextStyle()
                    .bigText("$settingCount setting(s) modified for $appLabel. Auto-revert is off — tap Revert Now when you're done."))
                .addAction(
                    Notification.Action.Builder(
                        null, "Revert Now", revertPendingIntent
                    ).build()
                )
        }

        val manager = context.getSystemService(NotificationManager::class.java)
        manager.notify(APPLY_NOTIFICATION_ID, builder.build())
    }

    fun showReverted(context: Context, appLabel: String, settingCount: Int) {
        createStatusChannel(context)
        val notification = Notification.Builder(context, STATUS_CHANNEL_ID)
            .setContentTitle("Settings Reverted")
            .setContentText("$settingCount setting(s) restored after leaving $appLabel")
            .setSmallIcon(R.drawable.ic_notification)
            .setAutoCancel(true)
            .build()

        val manager = context.getSystemService(NotificationManager::class.java)
        manager.notify(REVERT_NOTIFICATION_ID, notification)
    }

    fun showTimedOut(context: Context, appLabel: String, settingCount: Int) {
        createStatusChannel(context)
        val notification = Notification.Builder(context, STATUS_CHANNEL_ID)
            .setContentTitle("Monitoring Timed Out")
            .setContentText("$settingCount setting(s) reverted for $appLabel after timeout")
            .setSmallIcon(R.drawable.ic_notification)
            .setAutoCancel(true)
            .setStyle(Notification.BigTextStyle()
                .bigText("Monitoring for $appLabel reached the maximum duration. $settingCount setting(s) have been automatically reverted."))
            .build()

        val manager = context.getSystemService(NotificationManager::class.java)
        manager.notify(REVERT_NOTIFICATION_ID, notification)
    }

    fun showRevertFailed(context: Context) {
        createStatusChannel(context)
        val notification = Notification.Builder(context, STATUS_CHANNEL_ID)
            .setContentTitle("Revert Failed")
            .setContentText("Could not find settings to revert. Open ExpressPass to revert manually.")
            .setSmallIcon(R.drawable.ic_notification)
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
            .setSmallIcon(R.drawable.ic_notification)
            .setAutoCancel(true)
            .build()

        val manager = context.getSystemService(NotificationManager::class.java)
        manager.notify(REVERT_NOTIFICATION_ID, notification)
    }
}
