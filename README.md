# One UI Shell — repaired launcher + Fire OS Android bridge

This package contains the updated `OneUIShell.gd` and the source for a Godot 4.7.2 Android plugin named `FireOSTabletBridge`.

## What was fixed in the GDScript

- Corrected the right-anchored Quick Settings panel width/offset calculation.
- Corrected notification/Quick Settings animation endpoints so the panel's `offset_top = 48` is not added a second time.
- Added viewport resize handling and responsive grid/panel recalculation.
- Added native app discovery and Android launcher icons when the bridge is installed; retains the 12-entry fallback list when it is not.
- Routed package and Android Intent launching through the native bridge.
- Connected dynamically recreated notification buttons to UI sounds.
- Added notification listener polling and duplicate suppression.
- Added native daily alarm scheduling/cancellation, including reboot rescheduling, in addition to the in-app foreground alarm UI.
- Fixed multiple alarms at the same minute so they trigger one combined in-app alarm instead of silently ignoring all but the first.
- Added Android brightness, media volume, Wi-Fi, Bluetooth, DND, auto-rotate, immersive system-bar, device-lock, notification-access, and default-home integration hooks.
- Preserved the existing home screen, split notification/Quick Settings shade, app drawer, sound settings, custom audio import, alarms, lock screen, and gestures.

## Android integration included

The Android library source is in `android-plugin/`. The Godot export addon is in `addons/FireOSTabletBridge/`.

The bridge provides:

- Discover launchable installed apps, names and PNG icons.
- Launch installed packages and Android Intent URIs.
- Read battery, Wi-Fi, Bluetooth, airplane-mode and auto-rotate state.
- Hide Android status/navigation bars in immersive mode so the launcher's own tablet status/navigation UI does not double up, and control the real media-stream volume.
- Request and apply screen brightness changes after the user grants Modify System Settings access.
- Request DND policy access and toggle DND after the user grants it.
- Toggle Wi-Fi and Bluetooth where Fire OS permits the app to do so; if rejected, the launcher opens the corresponding system settings page.
- Receive real Android notifications after the user enables Notification Access.
- Schedule daily Android AlarmManager alarms that can fire while the Godot process is closed and be rescheduled after reboot.
- Request Device Administrator access and lock the tablet after the user enables it.
- Add the Android HOME/DEFAULT intent filter so Android can offer the app as a Home app.

## Build the AAR with GitHub Actions

The tablet-only workflow is:

1. Copy this package's `OneUIShell.gd`, `addons/`, `android-plugin/`, and `.github/` folders into the root of your Godot project/repository. Do not put them inside another nested folder.
2. Commit and push the files to GitHub.
3. Open the repository's **Actions** tab.
4. Select **Build Fire OS Android Bridge** and run it, or push a change under `android-plugin/`.
5. The workflow builds debug and release AAR files, copies them into `addons/FireOSTabletBridge/bin/`, and commits the generated AARs back to the branch.
6. Wait for the workflow to finish successfully. Confirm that these two files now exist in the repository:
   - `addons/FireOSTabletBridge/bin/debug/FireOSTabletBridge.aar`
   - `addons/FireOSTabletBridge/bin/release/FireOSTabletBridge.aar`

The build uses Java 17, Gradle 8.9, Android Gradle Plugin 8.7.3, and the Godot 4.7.2 Android library from Maven Central.

## Enable the Godot addon and export

1. In Godot, open **Project > Project Settings > Plugins**.
2. Enable **Fire OS Tablet Bridge**.
3. Choose **Project > Install Android Build Template** if the project does not already have the Gradle Android template installed.
4. Open **Project > Export**, select/create the Android preset, and enable **Gradle Build > Use Gradle Build**.
5. Export/install the APK on the Fire HD 10.
6. On first use, open the launcher Quick Settings > Sound & Alarms > Android access buttons as needed.

## Android permission setup

- **Notification Access:** enable `One UI Shell Notification Access` in Android/Fire OS Notification Access settings. This is required for real notification collection.
- **Modify System Settings:** grant One UI Shell permission on the Android screen opened by the brightness/rotation controls. Without it, brightness falls back to the launcher's visual dimmer.
- **Do Not Disturb:** grant Notification Policy access when prompted.
- **Device lock:** tap **Device lock** and approve the Device Administrator prompt. This is only used to lock the device when you explicitly tap that control. You can revoke it in system settings.
- **Default Home app:** choose One UI Shell in the system Home/default-app chooser if Fire OS exposes that choice. The app cannot silently make itself the default launcher.

## Important platform limits

- This is a custom launcher application, not Samsung One UI firmware. Fire OS can restrict which apps may become the default Home app.
- Airplane mode cannot be switched directly by an ordinary third-party app; the tile opens Fire OS settings instead.
- Wi-Fi and Bluetooth direct toggles are attempted but can be rejected by OS policy. The launcher opens the appropriate system page if rejected.
- Brightness and auto-rotate require the user-granted Modify System Settings permission.
- DND requires Notification Policy access.
- Device locking requires explicit Device Administrator activation.
- Android notifications require the user to enable Notification Access. The last 50 notification titles/texts are cached in the app's private SharedPreferences (not uploaded). The first poll ignores old cached entries but includes events posted after launcher startup.
- Native daily alarms can fire while the Godot process is closed and are restored after reboot. Their OS notification uses the Android default notification sound; the custom in-launcher alarm sound plays while the launcher is active. This is not a full-screen alarm-clock replacement and OEM battery policies may delay background delivery.
- The media card remains a visual placeholder; it does not control Amazon Music or arbitrary media sessions.
- Godot's built-in FileDialog may not expose every shared-storage location on Fire OS. Custom sound import still depends on the picker being able to read the selected file. A Storage Access Framework picker can be added separately if the current picker is blocked on the tablet.
- The app registry fallback is retained for editor/desktop preview. Native app discovery runs only in an Android export with the AAR loaded.

## Files

- `OneUIShell.gd` — complete replacement script for the same root `Control` node.
- `addons/FireOSTabletBridge/` — Godot v2 Android plugin export addon.
- `android-plugin/` — Java Android library source and manifest.
- `.github/workflows/build-android-bridge.yml` — browser-driven GitHub Actions AAR build.

## Validation status

The GDScript and Java source have been edited from the uploaded `OneUIShell.gd` and reviewed for integration consistency. This environment does not have Godot 4.7.2 or the Android SDK/Gradle build environment installed, so the project has **not** been parser-compiled, AAR-built, exported, or device-tested here. Treat the first GitHub Actions build and Godot export as the compile verification step; if either reports an error, share the full log and the exact Godot version.
