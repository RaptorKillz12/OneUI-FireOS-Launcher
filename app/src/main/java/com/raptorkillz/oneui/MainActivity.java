package com.raptorkillz.oneui;

import android.app.Activity;
import android.os.Bundle;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.GridLayout;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;
import android.widget.ImageView;
import android.widget.EditText;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.Date;
import java.util.List;
import java.util.Locale;

public class MainActivity extends Activity {
    private final int bg = Color.rgb(244,246,250);
    private final int ink = Color.rgb(25,28,35);
    private final int muted = Color.rgb(103,111,126);
    private final int blue = Color.rgb(52,120,246);
    private LinearLayout root;
    private boolean drawerOpen = false;
    private List<ResolveInfo> launchables = new ArrayList<>();

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().setStatusBarColor(bg);
        getWindow().setNavigationBarColor(bg);
        getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR | View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR);
        loadApps();
        showHome();
    }

    private void loadApps() {
        Intent query = new Intent(Intent.ACTION_MAIN, null);
        query.addCategory(Intent.CATEGORY_LAUNCHER);
        launchables = getPackageManager().queryIntentActivities(query, 0);
        Collections.sort(launchables, new Comparator<ResolveInfo>() {
            public int compare(ResolveInfo a, ResolveInfo b) {
                return a.loadLabel(getPackageManager()).toString().compareToIgnoreCase(b.loadLabel(getPackageManager()).toString());
            }
        });
    }

    private GradientDrawable shape(int color, int radius) {
        GradientDrawable d = new GradientDrawable();
        d.setColor(color);
        d.setCornerRadius(radius);
        return d;
    }

    private TextView text(String value, int size, int color, boolean bold) {
        TextView t = new TextView(this);
        t.setText(value);
        t.setTextSize(size);
        t.setTextColor(color);
        t.setGravity(Gravity.CENTER_VERTICAL);
        if (bold) t.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
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
        root.setBackgroundColor(bg);
        setContentView(root);
    }

    private void showHome() {
        drawerOpen = false;
        base();
        LinearLayout header = row();
        header.setPadding(24, 14, 24, 8);
        TextView date = text(new SimpleDateFormat("EEEE, MMMM d", Locale.getDefault()).format(new Date()), 14, muted, true);
        header.addView(date, new LinearLayout.LayoutParams(0, 44, 1));
        Button quick = smallButton("☼");
        quick.setOnClickListener(v -> showQuickPanel());
        header.addView(quick, lp(48, 44));
        root.addView(header);

        LinearLayout content = column();
        content.setPadding(22, 12, 22, 8);
        TextView clock = text(new SimpleDateFormat("h:mm", Locale.getDefault()).format(new Date()), 48, ink, false);
        content.addView(clock, lp(-1, 62));
        TextView greeting = text("Good day", 17, muted, false);
        content.addView(greeting, lp(-1, 30));
        LinearLayout weather = column();
        weather.setPadding(20, 16, 20, 16);
        weather.setBackground(shape(Color.WHITE, 28));
        TextView weatherTitle = text("Weather", 16, ink, true);
        weather.addView(weatherTitle, lp(-1, 28));
        weather.addView(text("Add a weather provider to show local conditions", 13, muted, false), lp(-1, 28));
        LinearLayout.LayoutParams wp = lp(-1, 88); wp.topMargin = 12;
        content.addView(weather, wp);

        EditText search = new EditText(this);
        search.setSingleLine(true);
        search.setTextSize(15);
        search.setHint("Search apps");
        search.setPadding(18, 0, 18, 0);
        search.setBackground(shape(Color.WHITE, 30));
        LinearLayout.LayoutParams sp = lp(-1, 52); sp.topMargin = 18;
        content.addView(search, sp);
        search.setOnEditorActionListener((v, action, event) -> { showDrawer(search.getText().toString()); return true; });
        root.addView(content);

        TextView section = text("Favorite apps", 17, ink, true);
        section.setPadding(24, 12, 24, 6);
        root.addView(section, lp(-1, 38));
        ScrollView scroll = new ScrollView(this);
        GridLayout grid = new GridLayout(this);
        grid.setColumnCount(4);
        addAppTiles(grid, Math.min(8, launchables.size()));
        scroll.addView(grid);
        root.addView(scroll, new LinearLayout.LayoutParams(-1, 0, 1));

        LinearLayout footer = row();
        footer.setGravity(Gravity.CENTER);
        footer.setPadding(16, 8, 16, 14);
        Button all = smallButton("All apps");
        all.setOnClickListener(v -> showDrawer(""));
        Button settings = smallButton("Settings");
        settings.setOnClickListener(v -> openSystemSettings());
        footer.addView(all, new LinearLayout.LayoutParams(0, 48, 1));
        footer.addView(settings, new LinearLayout.LayoutParams(0, 48, 1));
        root.addView(footer);
    }

    private void addAppTiles(GridLayout grid, int count) {
        for (int i=0; i<count; i++) addTile(grid, launchables.get(i));
    }

    private void addTile(GridLayout grid, ResolveInfo info) {
        LinearLayout tile = column();
        tile.setGravity(Gravity.CENTER);
        tile.setPadding(4, 8, 4, 8);
        ImageView icon = new ImageView(this);
        try { icon.setImageDrawable(info.loadIcon(getPackageManager())); } catch(Exception ignored) {}
        tile.addView(icon, lp(48,48));
        TextView label = text(info.loadLabel(getPackageManager()).toString(), 11, ink, false);
        label.setGravity(Gravity.CENTER);
        label.setMaxLines(2);
        tile.addView(label, lp(-1, 34));
        tile.setOnClickListener(v -> launch(info));
        GridLayout.LayoutParams p = new GridLayout.LayoutParams();
        p.width = getResources().getDisplayMetrics().widthPixels / 4;
        p.height = 104;
        grid.addView(tile, p);
    }

    private void showDrawer(String filter) {
        drawerOpen = true;
        base();
        LinearLayout top = row(); top.setPadding(22, 14, 22, 12);
        TextView title = text("Apps", 28, ink, true);
        top.addView(title, new LinearLayout.LayoutParams(0, 52, 1));
        Button close = smallButton("Home");
        close.setOnClickListener(v -> showHome());
        top.addView(close, lp(76,44));
        root.addView(top);
        EditText search = new EditText(this);
        search.setSingleLine(true); search.setText(filter); search.setHint("Find an app");
        search.setPadding(18,0,18,0); search.setBackground(shape(Color.WHITE,28));
        LinearLayout.LayoutParams ep=lp(-1,52); ep.setMargins(20,0,20,12); root.addView(search,ep);
        ScrollView scroll = new ScrollView(this);
        GridLayout grid = new GridLayout(this); grid.setColumnCount(4);
        for (ResolveInfo info : launchables) {
            String label=info.loadLabel(getPackageManager()).toString();
            if (filter == null || filter.isEmpty() || label.toLowerCase(Locale.ROOT).contains(filter.toLowerCase(Locale.ROOT))) addTile(grid,info);
        }
        scroll.addView(grid); root.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));
        search.addTextChangedListener(new android.text.TextWatcher() {
            public void beforeTextChanged(CharSequence s,int st,int c,int a) {}
            public void onTextChanged(CharSequence s,int st,int before,int count) { showDrawerGrid(grid,s.toString()); }
            public void afterTextChanged(android.text.Editable e) {}
        });
    }

    private void showDrawerGrid(GridLayout grid, String filter) {
        grid.removeAllViews();
        for (ResolveInfo info : launchables) {
            String label=info.loadLabel(getPackageManager()).toString();
            if (label.toLowerCase(Locale.ROOT).contains(filter.toLowerCase(Locale.ROOT))) addTile(grid,info);
        }
    }

    private void showQuickPanel() {
        base();
        LinearLayout panel=column(); panel.setPadding(24,24,24,24);
        TextView title=text("Quick settings",28,ink,true); panel.addView(title,lp(-1,60));
        String[] actions={"Wi-Fi settings","Bluetooth settings","Display settings","Sound settings","Battery settings","Device settings"};
        String[] intents={android.provider.Settings.ACTION_WIFI_SETTINGS,android.provider.Settings.ACTION_BLUETOOTH_SETTINGS,android.provider.Settings.ACTION_DISPLAY_SETTINGS,android.provider.Settings.ACTION_SOUND_SETTINGS,android.provider.Settings.ACTION_BATTERY_SAVER_SETTINGS,android.provider.Settings.ACTION_SETTINGS};
        for(int i=0;i<actions.length;i++){ final String action=intents[i]; Button b=smallButton(actions[i]); b.setOnClickListener(v->{try{startActivity(new Intent(action));}catch(Exception e){openSystemSettings();}}); LinearLayout.LayoutParams p=lp(-1,58);p.topMargin=8;panel.addView(b,p); }
        Button back=smallButton("Back to home"); back.setOnClickListener(v->showHome()); panel.addView(back,lp(-1,54));
        root.addView(panel);
    }

    private void openSystemSettings() {
        try { startActivity(new Intent(android.provider.Settings.ACTION_SETTINGS)); }
        catch(Exception e) { Toast.makeText(this,"Settings could not be opened",Toast.LENGTH_SHORT).show(); }
    }

    private Button smallButton(String label) {
        Button b=new Button(this); b.setText(label); b.setTextColor(ink); b.setAllCaps(false); b.setTextSize(14);
        b.setBackground(shape(Color.WHITE,24)); return b;
    }

    private void launch(ResolveInfo info) {
        try {
            Intent i=getPackageManager().getLaunchIntentForPackage(info.activityInfo.packageName);
            if(i!=null) startActivity(i);
        } catch(Exception e) { Toast.makeText(this,"Unable to launch app",Toast.LENGTH_SHORT).show(); }
    }

    @Override public void onBackPressed() {
        if(drawerOpen) showHome(); else super.onBackPressed();
    }
}
