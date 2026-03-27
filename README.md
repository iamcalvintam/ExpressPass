# ExpressPass

Temporarily modify Android device settings before launching sensitive apps (like banking), then automatically revert them when you leave the app. Think of it as an "express pass" that fast-tracks you through security checks.

## Why?

Many banking and security-sensitive apps detect Developer Options, USB debugging, accessibility services, and other settings, then refuse to run. ExpressPass solves this by:

1. Temporarily disabling those settings before launching the target app
2. Automatically re-enabling them when you switch away
3. Notifying you at every step so you always know what's happening

## Features

- **Per-app setting profiles** - Configure which settings to modify for each app
- **One-tap launch** - Apply settings and launch the app in a single tap
- **Auto-revert** - Foreground service monitors app usage and reverts settings when you leave
- **Setting templates** - Pre-built configurations for common settings (Developer Options, USB Debugging, etc.)
- **Home screen shortcuts** - Pin shortcuts for instant apply-and-launch
- **Notifications** - Get notified when settings are applied and reverted
- **Material 3 UI** - Modern interface with dynamic color support
- **Dark mode** - Full light/dark theme support

## Screenshots

The app has three main screens:

- **Home** - Grid of installed apps split into "Configured" (quick access) and "All Apps" sections
- **App Settings** - Configure per-app setting profiles with live current value display
- **Settings** - Theme, permissions, and about

## Requirements

- Android 8.0 (API 26) or higher
- `WRITE_SECURE_SETTINGS` permission (granted via ADB)
- Usage Access permission (for auto-revert)
- Notification permission (for status notifications)

## Getting Started

### Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) 3.22.3 or later
- Android SDK with platform tools
- A physical Android device (emulators cannot grant `WRITE_SECURE_SETTINGS`)

### Build & Install

```bash
# Clone the repository
git clone <repo-url>
cd expresspass

# Install dependencies
flutter pub get

# Build release APK
flutter build apk --release

# Install on device
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Grant Permissions

The app requires a special permission that can only be granted via ADB:

```bash
adb shell pm grant com.expresspass.expresspass android.permission.WRITE_SECURE_SETTINGS
```

The remaining permissions (Usage Access, Notifications) are requested through the in-app onboarding flow.

## How It Works

1. **Configure** - Select an app and choose which settings to modify (or use templates)
2. **Launch** - Tap "Apply & Launch" to modify settings and open the target app
3. **Use** - Use the target app normally while ExpressPass monitors in the background
4. **Auto-revert** - When you leave the target app, settings are automatically restored

### Technical Details

ExpressPass uses Android platform channels to interact with:

- **`Settings.System`** / **`Settings.Secure`** / **`Settings.Global`** - Read and write device settings
- **`UsageStatsManager`** - Monitor which app is in the foreground
- **`ShortcutManager`** - Create pinned home screen shortcuts
- **Foreground Service** - Keep monitoring alive while the target app is running

## Project Structure

```
lib/
  main.dart                           # Entry point
  app.dart                            # MaterialApp with theming and routing
  models/                             # Data classes
    app_setting.dart                  # AppSetting model + SettingType enum
    installed_app.dart                # InstalledApp model
    setting_template.dart             # Template model
  database/
    database_helper.dart              # SQLite CRUD operations
  services/                           # Platform channel wrappers
    settings_service.dart             # Read/write Android settings
    app_list_service.dart             # Query installed apps
    permission_service.dart           # Permission checks
    shortcut_service.dart             # Home screen shortcuts
    notification_service.dart         # Status notifications
    foreground_service_controller.dart # Monitor service lifecycle
    launch_orchestrator.dart          # Apply -> Launch -> Monitor flow
    template_service.dart             # Load bundled templates
    deep_link_service.dart            # Handle shortcut deep links
  providers/                          # State management (ChangeNotifier)
    app_list_provider.dart            # App list with search and filtering
    app_settings_provider.dart        # Per-app settings CRUD
    permission_provider.dart          # Permission state
    theme_provider.dart               # Theme preferences
  screens/
    onboarding/                       # Permission setup wizard
    app_list/                         # Home screen with app grid
    app_settings/                     # Per-app configuration
    settings/                         # App preferences

android/.../kotlin/
  MainActivity.kt                     # Platform channel registration
  channels/
    SettingsChannelHandler.kt         # Settings read/write bridge
    PackageManagerHandler.kt          # App list and launch
    PermissionHandler.kt              # Permission checks
    ShortcutHandler.kt                # Pinned shortcuts
  services/
    AppMonitorService.kt              # Foreground service for auto-revert
  receivers/
    RevertSettingsReceiver.kt         # Notification "Revert Now" action
  NotificationHelper.kt              # Status notification helper
```

## Available Setting Templates

| Template | Type | Key | Description |
|----------|------|-----|-------------|
| Disable Developer Options | Global | `development_settings_enabled` | Turns off Developer Options |
| Disable USB Debugging | Global | `adb_enabled` | Turns off ADB/USB debugging |
| Disable Wireless Debugging | Global | `adb_wifi_enabled` | Turns off wireless ADB |
| Disable Mock Locations | Secure | `mock_location` | Disables mock location providers |
| Disable Accessibility Services | Secure | `accessibility_enabled` | Turns off accessibility services |
| Disable Auto-Rotate | System | `accelerometer_rotation` | Locks screen rotation |

You can also add custom settings manually by specifying the setting type, key, and values.

## License

This project is provided as-is for personal use.
