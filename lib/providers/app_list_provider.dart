import 'package:flutter/foundation.dart';
import '../models/installed_app.dart';
import '../services/app_list_service.dart';
import '../database/database_helper.dart';

class AppListProvider extends ChangeNotifier {
  final AppListService _appListService = AppListService();
  final DatabaseHelper _db = DatabaseHelper();

  List<InstalledApp> _apps = [];
  List<InstalledApp> _filteredApps = [];
  String _searchQuery = '';
  bool _isLoading = false;
  String? _error;

  List<InstalledApp> get apps => _filteredApps;
  List<InstalledApp> get configuredApps =>
      _filteredApps.where((a) => a.settingsCount > 0).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;

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
      _applyFilter();
    } catch (e) {
      _error = 'Failed to load apps: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredApps = List.from(_apps);
    } else {
      final q = _searchQuery.toLowerCase();
      _filteredApps = _apps.where((app) {
        return app.label.toLowerCase().contains(q) ||
            app.packageName.toLowerCase().contains(q);
      }).toList();
    }
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
