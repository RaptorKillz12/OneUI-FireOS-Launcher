package com.raptorkillz.oneui;

import android.app.Activity;
import android.os.Bundle;
import android.content.Intent;
import android.content.pm.ResolveInfo;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.GridLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;
import android.widget.EditText;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Date;
import java.util.List;
import java.util.Locale;

public class MainActivity extends Activity {
    private final int surface = Color.rgb(245, 247, 251);
    private final int card = Color.rgb(255, 255, 255);
    private final int ink = Color.rgb(24, 27, 35);
    private final int muted = Color.rgb(100, 107, 123);
    private final int blue = Color.rgb(52, 120, 246);
    private LinearLayout root;
    private boolean drawerOpen = false;
    private List<ResolveInfo> launchables = new ArrayList<>();

    @Override
    public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().setStatusBarColor(surface);
        getWindow().setNavigationBarColor(surface);
        getWindow().getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR | View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR);
        loadApps();
        showHome();
    }

    private void loadApps() {
        Intent query = new Intent(Intent.ACTION_MAIN, null);
        query.addCategory(Intent.CATEGORY_LAUNCHER);
        launchables = getPackageManager().queryIntentActivities(query, 0);
        Collections.sort(launchables, (a, b) -> a.loadLabel(getPackageManager()).toString()
                .compareToIgnoreCase(b.loadLabel(getPackageManager()).toString()));
    }

    private GradientDrawable shape(int color, int radius) {
        GradientDrawable d = new GradientDrawable();
        d.setColor(color);
        d.setCornerRadius(radius);
        return d;
    }

    private TextView label(String text, float size, int color, boolean bold) {
        TextView t = new TextView(this);
        t.setText(text);
        t.setTextSize(size);
        t.setTextColor(color);
        t.setGravity(Gravity.CENTER_VERTICAL);
        if (bold) t.setTypeface(Typeface.create("sans", Typeface.BOLD));
        return t;
    }

    private LinearLayout column() {
        LinearLayout l = new LinearLayout(this);
        l.setOrientation(LinearLayout.VERTICAL);
        return l;
    }

    private LinearLayout row() {
        LinearLayout l = new LinearLayout(this);
        l.setOrientation(LinearLayout.HORIZONTAL);
        l.setGravity(Gravity.CENTER_VERTICAL);
        return l;
    }

    private LinearLayout.LayoutParams lp(int w, int h) {
        return new LinearLayout.LayoutParams(w, h);
    }

    private void base() {
        root = column();
        root.setBackgroundColor(surface);
        setContentView(root);
    }

    private int px(int dp) {
        return (int) (dp * getResources().getDisplayMetrics().density);
    }

    private void showHome() {
        drawerOpen = false;
        base();

        LinearLayout status = row();
        status.setPadding(px(28), px(8), px(28), px(4));
        TextView time = label(new SimpleDateFormat("h:mm", Locale.getDefault()).format(new Date()), 14, ink, true);
        status.addView(time, new LinearLayout.LayoutParams(0, px(32), 1));
        TextView statusRight = label("●  Wi-Fi", 14, ink, false);
        statusRight.setGravity(Gravity.CENTER_VERTICAL | Gravity.END);
        status.addView(statusRight, lp(px(180), px(32)));
        root.addView(status, lp(-1, px(42)));

        LinearLayout content = row();
        content.setPadding(px(56), px(18), px(56), px(18));

        LinearLayout left = column();
        left.setLayoutParams(new LinearLayout.LayoutParams(0, -1, 1));
        left.setPadding(0, 0, px(18), 0);

        TextView clock = label(new SimpleDateFormat("h:mm", Locale.getDefault()).format(new Date()), 76, ink, false);
        left.addView(clock, lp(-1, px(92)));
        TextView date = label(new SimpleDateFormat("EEEE, MMMM d", Locale.getDefault()).format(new Date()), 18, muted, false);
        left.addView(date, lp(-1, px(34)));

        LinearLayout weather = column();
        weather.setPadding(px(22), px(18), px(22), px(18));
        weather.setBackground(shape(card, px(30)));
        LinearLayout.LayoutParams weatherParams = lp(-1, px(138));
        weatherParams.topMargin = px(18);
        weather.addView(label("☀  72°", 32, ink, false), lp(-1, px(44)));
        weather.addView(label("Mostly Sunny", 14, muted, false), lp(-1, px(28)));
        weather.addView(label("Fire OS tablet weather card", 12, muted, false), lp(-1, px(24)));
        left.addView(weather, weatherParams);

        LinearLayout right = column();
        right.setLayoutParams(new LinearLayout.LayoutParams(0, -1, 1));
        right.setPadding(px(18), 0, 0, 0);

        LinearLayout searchCard = row();
        searchCard.setPadding(px(16), 0, px(16), 0);
        searchCard.setBackground(shape(card, px(28)));
        TextView searchIcon = label("⌕", 22, muted, false);
        searchCard.addView(searchIcon, lp(px(34), px(56)));
        EditText search = new EditText(this);
        search.setHint("Search apps");
        search.setSingleLine(true);
        search.setTextSize(16);
        search.setTextColor(ink);
        search.setHintTextColor(muted);
        search.setBackground(null);
        searchCard.addView(search, new LinearLayout.LayoutParams(0, px(56), 1));
        search.setOnEditorActionListener((v, action, event) -> {
            showDrawer(search.getText().toString());
            return true;
        });
        right.addView(searchCard, lp(-1, px(56)));

        TextView appsTitle = label("Your apps", 18, ink, true);
        LinearLayout.LayoutParams titleParams = lp(-1, px(44));
        titleParams.topMargin = px(16);
        right.addView(appsTitle, titleParams);

        ScrollView appScroll = new ScrollView(this);
        GridLayout grid = new GridLayout(this);
        grid.setColumnCount(5);
        grid.setUseDefaultMargins(false);
        int count = Math.min(10, launchables.size());
        for (int i = 0; i < count; i++) addTile(grid, launchables.get(i), 5);
        appScroll.addView(grid);
        right.addView(appScroll, new LinearLayout.LayoutParams(-1, 0, 1));

        content.addView(left);
        content.addView(right);
        root.addView(content, new LinearLayout.LayoutParams(-1, 0, 1));

        LinearLayout dock = row();
        dock.setGravity(Gravity.CENTER);
        dock.setPadding(px(16), px(10), px(16), px(14));
        LinearLayout dockCard = row();
        dockCard.setGravity(Gravity.CENTER);
        dockCard.setPadding(px(12), px(8), px(12), px(8));
        dockCard.setBackground(shape(card, px(34)));

        Button all = dockButton("⋯  Apps");
        all.setOnClickListener(v -> showDrawer(""));
        dockCard.addView(all, lp(px(120), px(48)));
        Button quick = dockButton("☼  Quick settings");
        quick.setOnClickListener(v -> showQuickPanel());
        dockCard.addView(quick, lp(px(170), px(48)));
        Button settings = dockButton("⚙  Settings");
        settings.setOnClickListener(v -> openSystemSettings());
        dockCard.addView(settings, lp(px(130), px(48)));
        dock.addView(dockCard);
        root.addView(dock, lp(-1, px(76)));
    }

    private void addTile(GridLayout grid, ResolveInfo info, int columns) {
        LinearLayout tile = column();
        tile.setGravity(Gravity.CENTER);
        tile.setPadding(px(5), px(8), px(5), px(8));

        ImageView icon = new ImageView(this);
        try { icon.setImageDrawable(info.loadIcon(getPackageManager())); } catch (Exception ignored) {}
        tile.addView(icon, lp(px(54), px(54)));

        TextView appLabel = label(info.loadLabel(getPackageManager()).toString(), 11, ink, false);
        appLabel.setGravity(Gravity.CENTER);
        appLabel.setMaxLines(2);
        tile.addView(appLabel, lp(px(110), px(38)));
        tile.setOnClickListener(v -> launch(info));

        GridLayout.LayoutParams p = new GridLayout.LayoutParams();
        p.width = px(112);
        p.height = px(104);
        p.leftMargin = px(4);
        p.rightMargin = px(4);
        p.topMargin = px(4);
        p.bottomMargin = px(4);
        grid.addView(tile, p);
    }

    private void showDrawer(String filter) {
        drawerOpen = true;
        base();

        LinearLayout header = row();
        header.setPadding(px(28), px(16), px(28), px(10));
        header.addView(label("Apps", 30, ink, true), new LinearLayout.LayoutParams(0, px(56), 1));
        Button home = pillButton("Home");
        home.setOnClickListener(v -> showHome());
        header.addView(home, lp(px(90), px(44)));
        root.addView(header);

        EditText search = new EditText(this);
        search.setText(filter);
        search.setHint("Search apps");
        search.setTextSize(16);
        search.setTextColor(ink);
        search.setHintTextColor(muted);
        search.setPadding(px(20), 0, px(20), 0);
        search.setSingleLine(true);
        search.setBackground(shape(card, px(28)));
        LinearLayout.LayoutParams searchParams = lp(-1, px(54));
        searchParams.setMargins(px(28), 0, px(28), px(14));
        root.addView(search, searchParams);

        ScrollView scroll = new ScrollView(this);
        GridLayout grid = new GridLayout(this);
        grid.setColumnCount(getResources().getDisplayMetrics().widthPixels > px(900) ? 7 : 5);
        grid.setPadding(px(24), px(8), px(24), px(24));
        filterAndAdd(grid, filter);
        scroll.addView(grid);
        root.addView(scroll, new LinearLayout.LayoutParams(-1, 0, 1));

        search.addTextChangedListener(new android.text.TextWatcher() {
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
            public void onTextChanged(CharSequence s, int start, int before, int count) {
                grid.removeAllViews();
                filterAndAdd(grid, s.toString());
            }
            public void afterTextChanged(android.text.Editable s) {}
        });
    }

    private void filterAndAdd(GridLayout grid, String filter) {
        int columns = grid.getColumnCount();
        for (ResolveInfo info : launchables) {
            String name = info.loadLabel(getPackageManager()).toString();
            if (filter == null || filter.isEmpty() || name.toLowerCase(Locale.ROOT)
                    .contains(filter.toLowerCase(Locale.ROOT))) {
                addTile(grid, info, columns);
            }
        }
    }

    private void showQuickPanel() {
        base();

        LinearLayout panel = column();
        panel.setPadding(px(28), px(18), px(28), px(18));

        LinearLayout header = row();
        header.addView(label("Quick settings", 28, ink, true), new LinearLayout.LayoutParams(0, px(60), 1));
        Button home = pillButton("Done");
        home.setOnClickListener(v -> showHome());
        header.addView(home, lp(px(90), px(44)));
        panel.addView(header);

        GridLayout tiles = new GridLayout(this);
        tiles.setColumnCount(3);
        String[] names = {"Wi-Fi", "Bluetooth", "Display", "Sound", "Battery", "Device"};
        String[] actions = {
                android.provider.Settings.ACTION_WIFI_SETTINGS,
                android.provider.Settings.ACTION_BLUETOOTH_SETTINGS,
                android.provider.Settings.ACTION_DISPLAY_SETTINGS,
                android.provider.Settings.ACTION_SOUND_SETTINGS,
                android.provider.Settings.ACTION_BATTERY_SAVER_SETTINGS,
                android.provider.Settings.ACTION_SETTINGS
        };
        for (int i = 0; i < names.length; i++) {
            final String action = actions[i];
            Button tile = pillButton(names[i]);
            tile.setTextSize(16);
            tile.setOnClickListener(v -> {
                try { startActivity(new Intent(action)); }
                catch (Exception e) { openSystemSettings(); }
            });
            GridLayout.LayoutParams p = new GridLayout.LayoutParams();
            p.width = px(210);
            p.height = px(72);
            p.leftMargin = px(8);
            p.rightMargin = px(8);
            p.topMargin = px(8);
            p.bottomMargin = px(8);
            tiles.addView(tile, p);
        }
        panel.addView(tiles);
        panel.addView(label("System controls open the appropriate Fire OS settings screen.", 14, muted, false),
                lp(-1, px(50)));
        root.addView(panel);
    }

    private void openSystemSettings() {
        try { startActivity(new Intent(android.provider.Settings.ACTION_SETTINGS)); }
        catch (Exception e) { Toast.makeText(this, "Settings could not be opened", Toast.LENGTH_SHORT).show(); }
    }

    private Button dockButton(String text) {
        Button b = new Button(this);
        b.setText(text);
        b.setTextColor(ink);
        b.setAllCaps(false);
        b.setTextSize(14);
        b.setBackground(shape(Color.rgb(248,249,252), px(24)));
        return b;
    }

    private Button pillButton(String text) {
        Button b = new Button(this);
        b.setText(text);
        b.setTextColor(ink);
        b.setAllCaps(false);
        b.setTextSize(14);
        b.setBackground(shape(card, px(22)));
        return b;
    }

    private void launch(ResolveInfo info) {
        try {
            Intent i = getPackageManager().getLaunchIntentForPackage(info.activityInfo.packageName);
            if (i != null) startActivity(i);
        } catch (Exception e) {
            Toast.makeText(this, "Unable to launch app", Toast.LENGTH_SHORT).show();
        }
    }

    @Override
    public void onBackPressed() {
        if (drawerOpen) showHome();
        else super.onBackPressed();
    }
}
