import '../models/app_setting.dart';
import 'settings_service.dart';
import 'app_list_service.dart';
import 'foreground_service_controller.dart';
import 'notification_service.dart';
import 'permission_service.dart';
import 'active_session_service.dart';

class LaunchOrchestrator {
  final SettingsService _settingsService;
  final AppListService _appListService;
  final ForegroundServiceController _serviceController;
  final NotificationService _notificationService;
  final PermissionService _permissionService;
  final ActiveSessionService _sessionService;
  String _lastAppLabel = '';

  LaunchOrchestrator({
    required SettingsService settingsService,
    required AppListService appListService,
    required ForegroundServiceController serviceController,
    NotificationService? notificationService,
    PermissionService? permissionService,
    ActiveSessionService? sessionService,
  })  : _settingsService = settingsService,
        _appListService = appListService,
        _serviceController = serviceController,
        _notificationService = notificationService ?? NotificationService(),
        _permissionService = permissionService ?? PermissionService(),
        _sessionService = sessionService ?? ActiveSessionService();

  Future<LaunchResult> applyAndLaunch(
    String packageName,
    List<AppSetting> settings, {
    String appLabel = '',
    bool autoRevert = true,
  }) async {
    _lastAppLabel = appLabel.isNotEmpty ? appLabel : packageName;
    final enabledSettings = settings.where((s) => s.enabled).toList();
    if (enabledSettings.isEmpty) {
      return const LaunchResult(success: false, message: 'No enabled settings to apply');
    }

    // Fresh permission check before applying
    final hasPermission = await _permissionService.hasWriteSecureSettings();
    if (!hasPermission) {
      return const LaunchResult(
        success: false,
        message: 'WRITE_SECURE_SETTINGS permission was revoked. Re-grant via ADB.',
      );
    }

    // Apply all settings, abort on permission denied
    final failures = <SettingFailure>[];
    final applied = <AppSetting>[];
    var permissionDenied = false;

    for (final setting in enabledSettings) {
      final result = await _settingsService.writeSetting(
        setting.settingType,
        setting.key,
        setting.valueOnLaunch,
      );
      switch (result) {
        case WriteResult.success:
          applied.add(setting);
        case WriteResult.permissionDenied:
          permissionDenied = true;
          break;
        case WriteResult.failed:
          failures.add(SettingFailure(
            label: setting.label,
            reason: 'Failed to write setting',
          ));
      }
      if (permissionDenied) break;
    }

    // If permission was denied mid-flow, revert what we already applied
    if (permissionDenied) {
      for (final setting in applied) {
        await _settingsService.writeSetting(
          setting.settingType,
          setting.key,
          setting.valueOnRevert,
        );
      }
      return const LaunchResult(
        success: false,
        message: 'Permission denied while applying settings. All changes reverted.',
      );
    }

    if (applied.isEmpty) {
      return const LaunchResult(
        success: false,
        message: 'Failed to apply settings. Check permissions.',
      );
    }

    // Notify that settings were applied
    await _notificationService.showApplied(_lastAppLabel, applied.length, autoRevert: autoRevert);
    await _sessionService.addSession(packageName, _lastAppLabel, applied.length);

    if (autoRevert) {
      try {
        await _serviceController.startMonitoring(packageName, settings);
      } catch (_) {}
    } else {
      await _serviceController.saveSettingsForRevert(settings);
    }

    // Launch the app
    final launched = await _appListService.launchApp(packageName);
    if (!launched) {
      await revertSettings(settings);
      return const LaunchResult(success: false, message: 'Failed to launch app');
    }

    if (failures.isNotEmpty) {
      return LaunchResult(
        success: true,
        message: 'Launched with ${failures.length} warning(s)',
        failedSettings: failures,
      );
    }

    final msg = autoRevert
        ? 'Settings applied and app launched'
        : 'Settings applied — remember to revert manually';
    return LaunchResult(success: true, message: msg);
  }

  Future<LaunchResult> applyOnly(
    String packageName,
    List<AppSetting> settings, {
    String appLabel = '',
  }) async {
    _lastAppLabel = appLabel.isNotEmpty ? appLabel : packageName;
    final enabledSettings = settings.where((s) => s.enabled).toList();
    if (enabledSettings.isEmpty) {
      return const LaunchResult(success: false, message: 'No enabled settings to apply');
    }

    final hasPermission = await _permissionService.hasWriteSecureSettings();
    if (!hasPermission) {
      return const LaunchResult(
        success: false,
        message: 'WRITE_SECURE_SETTINGS permission was revoked. Re-grant via ADB.',
      );
    }

    final failures = <SettingFailure>[];
    final applied = <AppSetting>[];

    for (final setting in enabledSettings) {
      final result = await _settingsService.writeSetting(
        setting.settingType,
        setting.key,
        setting.valueOnLaunch,
      );
      switch (result) {
        case WriteResult.success:
          applied.add(setting);
        case WriteResult.permissionDenied:
          // Revert what we applied
          for (final s in applied) {
            await _settingsService.writeSetting(s.settingType, s.key, s.valueOnRevert);
          }
          return const LaunchResult(
            success: false,
            message: 'Permission denied while applying settings. All changes reverted.',
          );
        case WriteResult.failed:
          failures.add(SettingFailure(label: setting.label, reason: 'Failed to write setting'));
      }
    }

    if (applied.isEmpty) {
      return const LaunchResult(success: false, message: 'Failed to apply settings.');
    }

    // Show persistent notification with revert action (no auto-revert for apply-only)
    await _notificationService.showApplied(_lastAppLabel, applied.length, autoRevert: false);
    await _serviceController.saveSettingsForRevert(settings);
    await _sessionService.addSession(packageName, _lastAppLabel, applied.length);

    if (failures.isNotEmpty) {
      return LaunchResult(
        success: true,
        message: 'Applied with ${failures.length} warning(s)',
        failedSettings: failures,
      );
    }

    return const LaunchResult(
      success: true,
      message: 'Settings applied — revert when done',
    );
  }

  Future<void> revertSettings(List<AppSetting> settings) async {
    final enabledSettings = settings.where((s) => s.enabled).toList();
    for (final setting in enabledSettings) {
      await _settingsService.writeSetting(
        setting.settingType,
        setting.key,
        setting.valueOnRevert,
      );
    }
    await _notificationService.showManualRevert(enabledSettings.length);
    // Remove all sessions since revert clears everything
    for (final setting in enabledSettings) {
      await _sessionService.removeSession(setting.packageName);
    }
    try {
      await _serviceController.stopMonitoring();
    } catch (_) {}
  }
}

class SettingFailure {
  final String label;
  final String reason;
  const SettingFailure({required this.label, required this.reason});
}

class LaunchResult {
  final bool success;
  final String message;
  final List<SettingFailure> failedSettings;

  const LaunchResult({
    required this.success,
    required this.message,
    this.failedSettings = const [],
  });
}
