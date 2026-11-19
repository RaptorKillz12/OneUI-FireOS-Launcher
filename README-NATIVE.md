# One UI Shell — Native Android build

This is the native Android implementation. It does not use Godot, GDScript, a Godot runtime, or Godot export templates.

## Build with GitHub Actions
Open **Actions → Build Native Android Launcher → Run workflow**. The workflow compiles the Android app with Java 17, Gradle 8.9 and Android SDK 35, then uploads a debug APK named `OneUI-Shell-debug`.

The APK is debug-signed by the Android Gradle plugin and can be installed directly. This first native milestone includes the One UI-inspired home screen, installed-app discovery and launching, app drawer/search, and quick links to Fire OS settings. It is a foundation; it does not yet reproduce every feature from the former Godot version.

## Set as Home app
Install the APK, open Fire OS Settings → Apps & Notifications → Default Apps → Home app (wording varies), then select **One UI Shell** if Fire OS exposes third-party launchers.

Fire OS may restrict default-launcher selection and some Android settings actions.
