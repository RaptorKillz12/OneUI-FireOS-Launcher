package com.raptorkillz.fireosbridge;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import java.util.Map;

public final class LauncherBootReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        if (!Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) return;
        SharedPreferences prefs = context.getSharedPreferences(AlarmScheduler.PREFS, Context.MODE_PRIVATE);
        for (Map.Entry<String, ?> entry : prefs.getAll().entrySet()) {
            String key = entry.getKey();
            if (!key.startsWith("alarm_") || !key.endsWith("_enabled") || !Boolean.TRUE.equals(entry.getValue())) continue;
            try {
                int id = Integer.parseInt(key.substring(6, key.length() - 8));
                int hour = prefs.getInt("alarm_" + id + "_hour", 7);
                int minute = prefs.getInt("alarm_" + id + "_minute", 0);
                AlarmScheduler.scheduleNext(context, hour, minute, id);
            } catch (Exception ignored) { }
        }
    }
}
