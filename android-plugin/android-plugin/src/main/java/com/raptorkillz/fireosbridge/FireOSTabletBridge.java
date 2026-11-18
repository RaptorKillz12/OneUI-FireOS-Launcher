package com.raptorkillz.fireosbridge;

import android.app.Activity;
import android.app.AlarmManager;
import android.app.NotificationManager;
import android.media.AudioManager;
import android.view.View;
import android.app.admin.DevicePolicyManager;
import android.bluetooth.BluetoothAdapter;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.drawable.Drawable;
import android.net.wifi.WifiManager;
import android.os.BatteryManager;
import android.os.Build;
import android.provider.Settings;
import android.util.Base64;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;
import org.json.JSONArray;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

public final class FireOSTabletBridge extends GodotPlugin {
    private static final String PREFS = "one_ui_shell_bridge";

    public FireOSTabletBridge(Godot godot) { super(godot); }

    @Override public String getPluginName() { return "FireOSTabletBridge"; }

    @Override public Set<String> getPluginMethods() {
        return new HashSet<>(Arrays.asList(
            "getInstalledAppsJson", "launchApp", "launchIntent", "openSettings",
            "getWifiEnabled", "setWifiEnabled", "getBluetoothEnabled", "setBluetoothEnabled",
            "getDndEnabled", "hasDndAccess", "setDndEnabled", "openDndAccessSettings",
            "getAutoRotateEnabled", "setAutoRotateEnabled", "getAirplaneModeEnabled",
            "canWriteSettings", "requestWriteSettingsPermission", "getScreenBrightness", "setScreenBrightness",
            "isNotificationAccessEnabled", "openNotificationAccessSettings", "getRecentNotificationsJson",
            "requestDeviceAdmin", "lockDevice", "scheduleDailyAlarm", "cancelDailyAlarm",
            "getBatteryPercent", "openHomeSettings", "setSystemBarsHidden",
            "getMediaVolume", "setMediaVolume"
        ));
    }

    private Activity activity() { return getActivity(); }
    private Context context() { return activity().getApplicationContext(); }

    @UsedByGodot public String getInstalledAppsJson() {
        JSONArray out = new JSONArray();
        try {
            PackageManager pm = context().getPackageManager();
            Intent query = new Intent(Intent.ACTION_MAIN, null);
            query.addCategory(Intent.CATEGORY_LAUNCHER);
            List<ResolveInfo> apps = pm.queryIntentActivities(query, 0);
            HashSet<String> seenPackages = new HashSet<>();
            for (ResolveInfo info : apps) {
                if (info.activityInfo == null) continue;
                String pkg = info.activityInfo.packageName;
                if (pkg.equals(context().getPackageName()) || seenPackages.contains(pkg)) continue;
                seenPackages.add(pkg);
                JSONObject item = new JSONObject();
                item.put("package", pkg);
                item.put("label", String.valueOf(info.loadLabel(pm)));
                item.put("icon", encodeIcon(info.loadIcon(pm)));
                out.put(item);
            }
        } catch (Exception ignored) { }
        return out.toString();
    }

    private String encodeIcon(Drawable drawable) {
        try {
            int w = Math.max(1, drawable.getIntrinsicWidth());
            int h = Math.max(1, drawable.getIntrinsicHeight());
            float scale = Math.min(96f / w, 96f / h);
            Bitmap bitmap = Bitmap.createBitmap(Math.max(1, (int)(w * scale)), Math.max(1, (int)(h * scale)), Bitmap.Config.ARGB_8888);
            Canvas canvas = new Canvas(bitmap);
            drawable.setBounds(0, 0, canvas.getWidth(), canvas.getHeight());
            drawable.draw(canvas);
            ByteArrayOutputStream stream = new ByteArrayOutputStream();
            bitmap.compress(Bitmap.CompressFormat.PNG, 90, stream);
            bitmap.recycle();
            return Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP);
        } catch (Exception e) { return ""; }
    }

    @UsedByGodot public boolean launchApp(String packageName) {
        try {
            Intent intent = context().getPackageManager().getLaunchIntentForPackage(packageName);
            if (intent == null) return false;
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            activity().startActivity(intent);
            return true;
        } catch (Exception e) { return false; }
    }

    @UsedByGodot public boolean launchIntent(String rawUri) {
        try {
            Intent intent;
            if (rawUri.startsWith("intent:")) {
                intent = Intent.parseUri(rawUri, Intent.URI_INTENT_SCHEME);
                if (intent.getPackage() != null && intent.getAction() == null) {
                    Intent launch = context().getPackageManager().getLaunchIntentForPackage(intent.getPackage());
                    if (launch != null) intent = launch;
                }
            } else {
                intent = new Intent(Intent.ACTION_VIEW, android.net.Uri.parse(rawUri));
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            activity().startActivity(intent);
            return true;
        } catch (Exception e) { return false; }
    }

    @UsedByGodot public boolean openSettings(String action) {
        try {
            Intent intent = new Intent(action);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            activity().startActivity(intent);
            return true;
        } catch (Exception e) { return false; }
    }

    @UsedByGodot public boolean getWifiEnabled() {
        try { return ((WifiManager) context().getSystemService(Context.WIFI_SERVICE)).isWifiEnabled(); }
        catch (Exception e) { return false; }
    }

    @UsedByGodot public boolean setWifiEnabled(boolean enabled) {
        try { return ((WifiManager) context().getSystemService(Context.WIFI_SERVICE)).setWifiEnabled(enabled); }
        catch (Exception e) { return false; }
    }

    @UsedByGodot public boolean getBluetoothEnabled() {
        try { BluetoothAdapter a = BluetoothAdapter.getDefaultAdapter(); return a != null && a.isEnabled(); }
        catch (Exception e) { return false; }
    }

    @UsedByGodot public boolean setBluetoothEnabled(boolean enabled) {
        try {
            BluetoothAdapter a = BluetoothAdapter.getDefaultAdapter();
            if (a == null) return false;
            return enabled ? a.enable() : a.disable();
        } catch (Exception e) { return false; }
    }

    @UsedByGodot public boolean hasDndAccess() {
        NotificationManager nm = (NotificationManager) context().getSystemService(Context.NOTIFICATION_SERVICE);
        return nm != null && nm.isNotificationPolicyAccessGranted();
    }

    @UsedByGodot public boolean getDndEnabled() {
        NotificationManager nm = (NotificationManager) context().getSystemService(Context.NOTIFICATION_SERVICE);
        return nm != null && nm.getCurrentInterruptionFilter() == NotificationManager.INTERRUPTION_FILTER_NONE;
    }

    @UsedByGodot public boolean setDndEnabled(boolean enabled) {
        try {
            NotificationManager nm = (NotificationManager) context().getSystemService(Context.NOTIFICATION_SERVICE);
            if (nm == null || !nm.isNotificationPolicyAccessGranted()) return false;
            nm.setInterruptionFilter(enabled ? NotificationManager.INTERRUPTION_FILTER_NONE : NotificationManager.INTERRUPTION_FILTER_ALL);
            return true;
        } catch (Exception e) { return false; }
    }

    @UsedByGodot public void openDndAccessSettings() {
        try { activity().startActivity(new Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)); }
        catch (Exception ignored) { openSettings("android.settings.SETTINGS"); }
    }

    @UsedByGodot public boolean canWriteSettings() { return Build.VERSION.SDK_INT < 23 || Settings.System.canWrite(context()); }

    @UsedByGodot public void requestWriteSettingsPermission() {
        try {
            Intent i = new Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS, android.net.Uri.parse("package:" + context().getPackageName()));
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            activity().startActivity(i);
        } catch (Exception ignored) { }
    }

    @UsedByGodot public float getScreenBrightness() {
        try { return Settings.System.getInt(context().getContentResolver(), Settings.System.SCREEN_BRIGHTNESS, 180) / 255.0f; }
        catch (Exception e) { return 0.7f; }
    }

    @UsedByGodot public boolean setScreenBrightness(float value) {
        try {
            if (!canWriteSettings()) return false;
            int brightness = Math.max(1, Math.min(255, Math.round(value * 255.0f)));
            return Settings.System.putInt(context().getContentResolver(), Settings.System.SCREEN_BRIGHTNESS, brightness);
        } catch (Exception e) { return false; }
    }

    @UsedByGodot public boolean getAutoRotateEnabled() {
        try { return Settings.System.getInt(context().getContentResolver(), Settings.System.ACCELEROMETER_ROTATION, 1) == 1; }
        catch (Exception e) { return true; }
    }

    @UsedByGodot public boolean setAutoRotateEnabled(boolean enabled) {
        try {
            if (!canWriteSettings()) return false;
            return Settings.System.putInt(context().getContentResolver(), Settings.System.ACCELEROMETER_ROTATION, enabled ? 1 : 0);
        } catch (Exception e) { return false; }
    }

    @UsedByGodot public boolean getAirplaneModeEnabled() {
        try { return Settings.Global.getInt(context().getContentResolver(), Settings.Global.AIRPLANE_MODE_ON, 0) == 1; }
        catch (Exception e) { return false; }
    }

    @UsedByGodot public boolean isNotificationAccessEnabled() {
        String enabled = Settings.Secure.getString(context().getContentResolver(), "enabled_notification_listeners");
        return enabled != null && enabled.contains(context().getPackageName());
    }

    @UsedByGodot public void openNotificationAccessSettings() {
        try { activity().startActivity(new Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")); }
        catch (Exception ignored) { openSettings("android.settings.SETTINGS"); }
    }

    @UsedByGodot public String getRecentNotificationsJson() {
        return context().getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("recent_notifications", "[]");
    }

    @UsedByGodot public boolean requestDeviceAdmin() {
        try {
            ComponentName receiver = new ComponentName(context(), LauncherDeviceAdminReceiver.class);
            Intent intent = new Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN);
            intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, receiver);
            intent.putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, "Allows the Device lock button in One UI Shell to lock this tablet.");
            activity().startActivity(intent);
            return true;
        } catch (Exception e) { return false; }
    }

    @UsedByGodot public boolean lockDevice() {
        try {
            DevicePolicyManager dpm = (DevicePolicyManager) context().getSystemService(Context.DEVICE_POLICY_SERVICE);
            ComponentName receiver = new ComponentName(context(), LauncherDeviceAdminReceiver.class);
            if (dpm != null && dpm.isAdminActive(receiver)) { dpm.lockNow(); return true; }
        } catch (Exception ignored) { }
        return false;
    }

    @UsedByGodot public void scheduleDailyAlarm(int hour, int minute, int id) {
        AlarmScheduler.schedule(context(), hour, minute, id);
    }

    @UsedByGodot public void cancelDailyAlarm(int id) { AlarmScheduler.cancel(context(), id); }

    @UsedByGodot public void setSystemBarsHidden(boolean hidden) {
        try {
            activity().runOnUiThread(() -> {
                View decor = activity().getWindow().getDecorView();
                int flags = View.SYSTEM_UI_FLAG_LAYOUT_STABLE;
                if (hidden) {
                    flags |= View.SYSTEM_UI_FLAG_FULLSCREEN | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION |
                        View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN |
                        View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION;
                }
                decor.setSystemUiVisibility(flags);
            });
        } catch (Exception ignored) { }
    }

    @UsedByGodot public float getMediaVolume() {
        try {
            AudioManager audio = (AudioManager) context().getSystemService(Context.AUDIO_SERVICE);
            if (audio == null) return 0.5f;
            int max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC);
            return max <= 0 ? 0.0f : audio.getStreamVolume(AudioManager.STREAM_MUSIC) / (float) max;
        } catch (Exception e) { return 0.5f; }
    }

    @UsedByGodot public boolean setMediaVolume(float normalized) {
        try {
            AudioManager audio = (AudioManager) context().getSystemService(Context.AUDIO_SERVICE);
            if (audio == null) return false;
            int max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC);
            int value = Math.max(0, Math.min(max, Math.round(normalized * max)));
            audio.setStreamVolume(AudioManager.STREAM_MUSIC, value, 0);
            return true;
        } catch (Exception e) { return false; }
    }

    @UsedByGodot public int getBatteryPercent() {
        try {
            Intent battery = context().registerReceiver(null, new android.content.IntentFilter(Intent.ACTION_BATTERY_CHANGED));
            if (battery == null) return -1;
            int level = battery.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
            int scale = battery.getIntExtra(BatteryManager.EXTRA_SCALE, -1);
            return level >= 0 && scale > 0 ? Math.round(level * 100f / scale) : -1;
        } catch (Exception e) { return -1; }
    }

    @UsedByGodot public void openHomeSettings() {
        if (!openSettings("android.settings.HOME_SETTINGS")) openSettings("android.settings.MANAGE_DEFAULT_APPS_SETTINGS");
    }
}
