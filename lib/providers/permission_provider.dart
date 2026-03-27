import 'package:flutter/foundation.dart';
import '../services/permission_service.dart';

class PermissionProvider extends ChangeNotifier {
  final PermissionService _service = PermissionService();

  bool _writeSecureSettings = false;
  bool _usageStats = false;
  bool _notifications = false;
  bool _isChecking = false;

  bool get writeSecureSettings => _writeSecureSettings;
  bool get usageStats => _usageStats;
  bool get notifications => _notifications;
  bool get isChecking => _isChecking;
  bool get allGranted => _writeSecureSettings && _usageStats && _notifications;

  Future<void> checkAll() async {
    _isChecking = true;
    notifyListeners();

    _writeSecureSettings = await _service.hasWriteSecureSettings();
    _usageStats = await _service.hasUsageStatsPermission();
    _notifications = await _service.hasNotificationPermission();

    _isChecking = false;
    notifyListeners();
  }

  Future<void> requestUsageStats() async {
    await _service.requestUsageStatsPermission();
  }

  Future<bool> requestNotifications() async {
    final granted = await _service.requestNotificationPermission();
    _notifications = granted;
    notifyListeners();
    return granted;
  }

  Future<void> openNotificationSettings() async {
    await _service.openNotificationSettings();
  }

  Future<String> getAdbCommand() async {
    return _service.getAdbCommand();
  }
}
