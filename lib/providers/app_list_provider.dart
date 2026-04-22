import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/installed_app.dart';
import '../services/app_list_service.dart';
import '../database/database_helper.dart';

class AppListProvider extends ChangeNotifier {
  final AppListService _appListService = AppListService();
  final DatabaseHelper _db = DatabaseHelper();

  static const availableTags = ['Banking', 'Gaming', 'Work', 'Social', 'Media'];

  List<InstalledApp> _apps = [];
  List<InstalledApp> _filteredApps = [];
  String _searchQuery = '';
  String? _activeTagFilter;
  bool _isLoading = false;
  String? _error;
  Map<String, String> _appTags = {}; // packageName -> tag

  List<InstalledApp> get apps => _filteredApps;
  List<InstalledApp> get configuredApps =>
      _filteredApps.where((a) => a.settingsCount > 0).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String? get activeTagFilter => _activeTagFilter;
  Map<String, String> get appTags => _appTags;

  Future<void> loadApps() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _apps = await _appListService.getInstalledApps();
      final counts = await _db.getSettingsCountByPackage();
      _apps = _apps.map((app) {
        final count = counts[app.packageName] ?? 0;
        return count > 0 ? app.copyWith(settingsCount: count) : app;
      }).toList();
      await _loadTags();
      _applyFilter();
    } catch (e) {
      _error = 'Failed to load apps: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadTags() async {
    final prefs = await SharedPreferences.getInstance();
    _appTags = {};
    for (final key in prefs.getKeys()) {
      if (key.startsWith('app_tag_')) {
        final pkg = key.substring('app_tag_'.length);
        _appTags[pkg] = prefs.getString(key) ?? '';
      }
    }
  }

  Future<void> setAppTag(String packageName, String? tag) async {
    final prefs = await SharedPreferences.getInstance();
    if (tag == null || tag.isEmpty) {
      _appTags.remove(packageName);
      await prefs.remove('app_tag_$packageName');
    } else {
      _appTags[packageName] = tag;
      await prefs.setString('app_tag_$packageName', tag);
    }
    _applyFilter();
    notifyListeners();
  }

  void setTagFilter(String? tag) {
    _activeTagFilter = tag;
    _applyFilter();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    var result = List<InstalledApp>.from(_apps);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((app) {
        return app.label.toLowerCase().contains(q) ||
            app.packageName.toLowerCase().contains(q);
      }).toList();
    }

    if (_activeTagFilter != null) {
      result = result.where((app) {
        return _appTags[app.packageName] == _activeTagFilter;
      }).toList();
    }

    _filteredApps = result;
  }

  Future<void> refreshSettingsCounts() async {
    final counts = await _db.getSettingsCountByPackage();
    _apps = _apps.map((app) {
      return app.copyWith(settingsCount: counts[app.packageName] ?? 0);
    }).toList();
    _applyFilter();
    notifyListeners();
  }
}
