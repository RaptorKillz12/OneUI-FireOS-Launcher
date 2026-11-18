package com.raptorkillz.fireosbridge;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

public final class LauncherAlarmReceiver extends BroadcastReceiver {
    private static final String CHANNEL = "one_ui_shell_alarms";

    @Override public void onReceive(Context context, Intent intent) {
        int id = intent.getIntExtra("alarm_id", 0);
        int hour = intent.getIntExtra("hour", 7);
        int minute = intent.getIntExtra("minute", 0);
        showAlarmNotification(context, id, hour, minute);
        AlarmScheduler.scheduleNext(context, hour, minute, id);
    }

    static void showAlarmNotification(Context context, int id, int hour, int minute) {
        NotificationManager nm = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (nm == null) return;
        if (Build.VERSION.SDK_INT >= 26) nm.createNotificationChannel(new NotificationChannel(CHANNEL, "Launcher alarms", NotificationManager.IMPORTANCE_HIGH));
        Intent launch = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
        PendingIntent content = launch == null ? null : PendingIntent.getActivity(context, id, launch, PendingIntent.FLAG_UPDATE_CURRENT | (Build.VERSION.SDK_INT >= 23 ? PendingIntent.FLAG_IMMUTABLE : 0));
        String time = String.format(java.util.Locale.getDefault(), "%02d:%02d", hour, minute);
        Notification.Builder builder = Build.VERSION.SDK_INT >= 26 ? new Notification.Builder(context, CHANNEL) : new Notification.Builder(context);
        builder.setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("Alarm")
            .setContentText("It's " + time)
            .setCategory(Notification.CATEGORY_ALARM)
            .setPriority(Notification.PRIORITY_MAX)
            .setAutoCancel(true)
            .setDefaults(Notification.DEFAULT_SOUND | Notification.DEFAULT_VIBRATE);
        if (content != null) builder.setContentIntent(content);
        nm.notify(10000 + Math.abs(id % 10000), builder.build());
    }
}
