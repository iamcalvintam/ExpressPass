import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_setting.dart';
import '../database/database_helper.dart';
import '../services/settings_service.dart';

class AppSettingsProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  final SettingsService _settingsService = SettingsService();

  List<AppSetting> _settings = [];
  Map<String, String?> _currentValues = {};
  bool _isLoading = false;
  String _packageName = '';
  bool _autoRevert = true;
  bool _skipConfirmation = false;

  List<AppSetting> get settings => _settings;
  Map<String, String?> get currentValues => _currentValues;
  bool get isLoading => _isLoading;
  bool get autoRevert => _autoRevert;
  bool get skipConfirmation => _skipConfirmation;

  Future<void> loadSettings(String packageName) async {
    _packageName = packageName;
    _isLoading = true;
    notifyListeners();

    _settings = await _db.getSettingsForPackage(packageName);
    await _loadCurrentValues();
    await _loadAutoRevert(packageName);
    await _loadSkipConfirmation(packageName);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadAutoRevert(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    _autoRevert = prefs.getBool('auto_revert_$packageName') ?? true;
  }

  Future<void> setAutoRevert(bool value) async {
    _autoRevert = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_revert_$_packageName', value);
    notifyListeners();
  }

  Future<void> _loadSkipConfirmation(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    _skipConfirmation = prefs.getBool('skip_confirm_$packageName') ?? false;
  }

  Future<void> setSkipConfirmation(bool value) async {
    _skipConfirmation = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('skip_confirm_$_packageName', value);
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

  /// Removes from in-memory list only. Call commitDelete() to persist, or undoRemove() to restore.
  (AppSetting, int)? removeSetting(int id) {
    final index = _settings.indexWhere((s) => s.id == id);
    if (index == -1) return null;
    final setting = _settings.removeAt(index);
    notifyListeners();
    return (setting, index);
  }

  void undoRemoveSetting(AppSetting setting, int index) {
    if (index <= _settings.length) {
      _settings.insert(index, setting);
    } else {
      _settings.add(setting);
    }
    notifyListeners();
  }

  Future<void> commitDelete(int id) async {
    await _db.deleteSetting(id);
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
