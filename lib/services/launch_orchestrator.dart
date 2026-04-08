import '../models/app_setting.dart';
import 'settings_service.dart';
import 'app_list_service.dart';
import 'foreground_service_controller.dart';
import 'notification_service.dart';

class LaunchOrchestrator {
  final SettingsService _settingsService;
  final AppListService _appListService;
  final ForegroundServiceController _serviceController;
  final NotificationService _notificationService;
  String _lastAppLabel = '';

  LaunchOrchestrator({
    required SettingsService settingsService,
    required AppListService appListService,
    required ForegroundServiceController serviceController,
    NotificationService? notificationService,
  })  : _settingsService = settingsService,
        _appListService = appListService,
        _serviceController = serviceController,
        _notificationService = notificationService ?? NotificationService();

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

    // Apply all settings
    final failures = <String>[];
    for (final setting in enabledSettings) {
      final success = await _settingsService.writeSetting(
        setting.settingType,
        setting.key,
        setting.valueOnLaunch,
      );
      if (!success) {
        failures.add(setting.label);
      }
    }

    if (failures.length == enabledSettings.length) {
      return const LaunchResult(
        success: false,
        message: 'Failed to apply settings. Check permissions.',
      );
    }

    // Notify that settings were applied
    final appliedCount = enabledSettings.length - failures.length;
    await _notificationService.showApplied(_lastAppLabel, appliedCount);

    // Start monitoring service only if auto-revert is enabled
    if (autoRevert) {
      try {
        await _serviceController.startMonitoring(packageName, settings);
      } catch (_) {
        // Service may fail but we can still launch
      }
    }

    // Launch the app
    final launched = await _appListService.launchApp(packageName);
    if (!launched) {
      // Revert settings since we couldn't launch
      await revertSettings(settings);
      return const LaunchResult(success: false, message: 'Failed to launch app');
    }

    if (failures.isNotEmpty) {
      return LaunchResult(
        success: true,
        message: 'Launched with warnings: failed to apply ${failures.join(", ")}',
      );
    }

    final msg = autoRevert
        ? 'Settings applied and app launched'
        : 'Settings applied — remember to revert manually';
    return LaunchResult(success: true, message: msg);
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
    // Notify that settings were reverted
    await _notificationService.showManualRevert(enabledSettings.length);
    try {
      await _serviceController.stopMonitoring();
    } catch (_) {}
  }
}

class LaunchResult {
  final bool success;
  final String message;

  const LaunchResult({required this.success, required this.message});
}
