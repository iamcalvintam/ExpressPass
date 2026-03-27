import 'package:flutter/foundation.dart';
import '../models/app_setting.dart';
import '../database/database_helper.dart';
import '../services/settings_service.dart';

class AppSettingsProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  final SettingsService _settingsService = SettingsService();

  List<AppSetting> _settings = [];
  Map<String, String?> _currentValues = {};
  bool _isLoading = false;
  // ignore: unused_field
  String _packageName = '';

  List<AppSetting> get settings => _settings;
  Map<String, String?> get currentValues => _currentValues;
  bool get isLoading => _isLoading;

  Future<void> loadSettings(String packageName) async {
    _packageName = packageName;
    _isLoading = true;
    notifyListeners();

    _settings = await _db.getSettingsForPackage(packageName);
    await _loadCurrentValues();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadCurrentValues() async {
    _currentValues = {};
    for (final setting in _settings) {
      final value = await _settingsService.readSetting(setting.settingType, setting.key);
      _currentValues[setting.key] = value;
    }
  }

  Future<void> addSetting(AppSetting setting) async {
    final id = await _db.insertSetting(setting);
    _settings.add(setting.copyWith(id: id));
    final value = await _settingsService.readSetting(setting.settingType, setting.key);
    _currentValues[setting.key] = value;
    notifyListeners();
  }

  Future<void> updateSetting(AppSetting setting) async {
    await _db.updateSetting(setting);
    final index = _settings.indexWhere((s) => s.id == setting.id);
    if (index != -1) {
      _settings[index] = setting;
      notifyListeners();
    }
  }

  Future<void> toggleSetting(AppSetting setting) async {
    final updated = setting.copyWith(enabled: !setting.enabled);
    await updateSetting(updated);
  }

  Future<void> deleteSetting(int id) async {
    await _db.deleteSetting(id);
    _settings.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  Future<void> refreshCurrentValues() async {
    await _loadCurrentValues();
    notifyListeners();
  }
}
