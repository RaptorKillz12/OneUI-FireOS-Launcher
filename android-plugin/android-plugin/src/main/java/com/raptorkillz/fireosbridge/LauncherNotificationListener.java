package com.raptorkillz.fireosbridge;

import android.app.Notification;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import android.content.Context;
import android.os.Bundle;
import org.json.JSONArray;
import org.json.JSONObject;

public final class LauncherNotificationListener extends NotificationListenerService {
    private static final String PREFS = "one_ui_shell_bridge";

    @Override public void onListenerConnected() {
        try {
            StatusBarNotification[] active = getActiveNotifications();
            if (active != null) for (StatusBarNotification notification : active) onNotificationPosted(notification);
        } catch (Exception ignored) { }
    }

    @Override public void onNotificationPosted(StatusBarNotification sbn) {
        if (sbn == null || getPackageName().equals(sbn.getPackageName())) return;
        try {
            Bundle extras = sbn.getNotification().extras;
            CharSequence titleValue = extras != null ? extras.getCharSequence(Notification.EXTRA_TITLE) : null;
            CharSequence textValue = extras != null ? extras.getCharSequence(Notification.EXTRA_TEXT) : null;
            String title = titleValue != null ? titleValue.toString() : "Notification";
            String text = textValue != null ? textValue.toString() : "";
            JSONObject item = new JSONObject();
            item.put("id", sbn.getPackageName() + ":" + sbn.getId() + ":" + sbn.getPostTime());
            String appLabel = sbn.getPackageName();
            try { appLabel = String.valueOf(getPackageManager().getApplicationLabel(getPackageManager().getApplicationInfo(sbn.getPackageName(), 0))); }
            catch (Exception ignored) { }
            item.put("app", appLabel);
            item.put("title", title);
            item.put("text", text);
            item.put("time", sbn.getPostTime());
            JSONArray old = new JSONArray(getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("recent_notifications", "[]"));
            JSONArray next = new JSONArray();
            next.put(item);
            for (int i = 0; i < old.length() && i < 49; i++) next.put(old.get(i));
            getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString("recent_notifications", next.toString()).apply();
        } catch (Exception ignored) { }
    }
}
