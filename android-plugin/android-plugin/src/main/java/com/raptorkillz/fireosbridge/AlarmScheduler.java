package com.raptorkillz.fireosbridge;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import java.util.Calendar;

final class AlarmScheduler {
    static final String PREFS = "one_ui_shell_bridge";
    static final String ACTION = "com.raptorkillz.fireosbridge.DAILY_ALARM";

    static void schedule(Context context, int hour, int minute, int id) {
        hour = Math.max(0, Math.min(23, hour));
        minute = Math.max(0, Math.min(59, minute));
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putInt("alarm_" + id + "_hour", hour).putInt("alarm_" + id + "_minute", minute)
            .putBoolean("alarm_" + id + "_enabled", true).apply();
        scheduleNext(context, hour, minute, id);
    }

    static void scheduleNext(Context context, int hour, int minute, int id) {
        Calendar c = Calendar.getInstance();
        c.set(Calendar.HOUR_OF_DAY, hour); c.set(Calendar.MINUTE, minute); c.set(Calendar.SECOND, 0); c.set(Calendar.MILLISECOND, 0);
        if (c.getTimeInMillis() <= System.currentTimeMillis()) c.add(Calendar.DAY_OF_YEAR, 1);
        Intent intent = new Intent(context, LauncherAlarmReceiver.class).setAction(ACTION).putExtra("alarm_id", id).putExtra("hour", hour).putExtra("minute", minute);
        PendingIntent pi = PendingIntent.getBroadcast(context, id, intent, PendingIntent.FLAG_UPDATE_CURRENT | (Build.VERSION.SDK_INT >= 23 ? PendingIntent.FLAG_IMMUTABLE : 0));
        AlarmManager manager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (manager == null) return;
        if (Build.VERSION.SDK_INT >= 23) manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, c.getTimeInMillis(), pi);
        else manager.setExact(AlarmManager.RTC_WAKEUP, c.getTimeInMillis(), pi);
    }

    static void cancel(Context context, int id) {
        Intent intent = new Intent(context, LauncherAlarmReceiver.class).setAction(ACTION);
        PendingIntent pi = PendingIntent.getBroadcast(context, id, intent, PendingIntent.FLAG_UPDATE_CURRENT | (Build.VERSION.SDK_INT >= 23 ? PendingIntent.FLAG_IMMUTABLE : 0));
        AlarmManager manager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (manager != null) manager.cancel(pi);
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .remove("alarm_" + id + "_hour").remove("alarm_" + id + "_minute").remove("alarm_" + id + "_enabled").apply();
    }
}
