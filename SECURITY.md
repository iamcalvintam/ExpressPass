# Security Policy

## About This App's Permissions

ExpressPass requires elevated Android permissions to function. This section explains why each permission is needed and how it is used.

### WRITE_SECURE_SETTINGS

**Why:** This is the core permission that allows ExpressPass to modify device settings like Developer Options and USB Debugging.

**How it's used:** Only writes to settings that the user has explicitly configured in a per-app profile. Settings are reverted to their original values when the target app is no longer in the foreground.

**How it's granted:** This permission cannot be granted through the normal app installation flow. It must be granted via ADB:
```bash
adb shell pm grant com.expresspass.expresspass android.permission.WRITE_SECURE_SETTINGS
```

### PACKAGE_USAGE_STATS

**Why:** Required to monitor which app is currently in the foreground, enabling automatic setting revert when you leave a configured app.

**How it's used:** The foreground service polls `UsageStatsManager` every 1 second to detect app transitions. No usage data is stored or transmitted.

### POST_NOTIFICATIONS

**Why:** Used to display status notifications when settings are applied or reverted.

**How it's used:** Notifications are purely local and informational. No data is sent externally.

### QUERY_ALL_PACKAGES

**Why:** Required to list all installed apps so you can select which ones to configure.

**How it's used:** App names and icons are displayed in the UI. No app inventory data is stored beyond the configured setting profiles.

## Data Storage

- All data is stored locally on the device in a SQLite database
- No data is transmitted to any server
- No analytics or telemetry is collected
- No user accounts or authentication is required

## Reporting a Vulnerability

If you discover a security vulnerability, please report it by opening a private issue or contacting the maintainers directly. Do not disclose vulnerabilities publicly until they have been addressed.
