# Contributing to ExpressPass

Thank you for your interest in contributing to ExpressPass!

## Development Setup

### Prerequisites

- Flutter 3.22.3 or later
- Android SDK (API 26+)
- Kotlin (bundled with Flutter's Gradle plugin)
- A physical Android device for testing

### Getting Started

```bash
# Clone the repo
git clone <repo-url>
cd expresspass

# Install Flutter dependencies
flutter pub get

# Run in debug mode
flutter run

# Grant the required permission on the connected device
adb shell pm grant com.expresspass.expresspass android.permission.WRITE_SECURE_SETTINGS
```

### Project Architecture

ExpressPass follows a layered architecture:

```
Screens (UI) -> Providers (State) -> Services (Platform Channels) -> Kotlin Handlers (Android APIs)
                                  -> Database (SQLite)
```

- **Models** (`lib/models/`) - Plain Dart data classes
- **Database** (`lib/database/`) - SQLite via sqflite, singleton pattern
- **Services** (`lib/services/`) - Thin wrappers around `MethodChannel` calls
- **Providers** (`lib/providers/`) - `ChangeNotifier` classes for state management via Provider
- **Screens** (`lib/screens/`) - Flutter widgets, one folder per screen
- **Kotlin Channels** (`android/.../channels/`) - `MethodCallHandler` implementations that bridge to Android APIs

### Key Files

| File | Purpose |
|------|---------|
| `lib/services/launch_orchestrator.dart` | Core workflow: apply settings, start monitoring, launch app |
| `android/.../channels/SettingsChannelHandler.kt` | Reads/writes `Settings.System/Secure/Global` |
| `android/.../services/AppMonitorService.kt` | Foreground service that polls `UsageStatsManager` |
| `lib/providers/app_settings_provider.dart` | Per-app settings CRUD with live value tracking |

### Code Style

- Follow standard Dart/Flutter conventions
- Use `flutter analyze` to check for issues before submitting
- Keep platform channel methods minimal - complex logic should live in Dart when possible
- Use Provider for state management (no Riverpod, Bloc, etc.)

### Testing

```bash
# Run static analysis
flutter analyze

# Build release to verify compilation
flutter build apk --release
```

### Adding a New Setting Template

1. Edit `assets/templates.json`
2. Add a new entry with `settingType`, `label`, `key`, `valueOnLaunch`, `valueOnRevert`, and `description`
3. The template will automatically appear in the template picker

### Adding a New Platform Channel Method

1. Add the method handler in the appropriate Kotlin `ChannelHandler` class
2. Add a corresponding method in the Flutter service class (`lib/services/`)
3. Call from providers or screens as needed

## Submitting Changes

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Run `flutter analyze` to ensure no issues
5. Build release to verify (`flutter build apk --release`)
6. Commit with a clear message
7. Push to your fork and open a Pull Request
