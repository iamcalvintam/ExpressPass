import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/app_setting.dart';

class BackupService {
  final DatabaseHelper _db = DatabaseHelper();

  Future<bool> exportSettings() async {
    final settings = await _db.getAllSettings();
    if (settings.isEmpty) return false;

    // Collect auto-revert preferences
    final prefs = await SharedPreferences.getInstance();
    final autoRevertPrefs = <String, bool>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith('auto_revert_')) {
        autoRevertPrefs[key] = prefs.getBool(key) ?? true;
      }
    }

    final exportData = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': settings.map((s) => s.toMap()).toList(),
      'preferences': autoRevertPrefs,
    };

    final json = const JsonEncoder.withIndent('  ').convert(exportData);

    // Write to temp file and share
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/expresspass_backup.json');
    await file.writeAsString(json);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'ExpressPass Backup',
    );
    return true;
  }

  Future<(int, int)> importSettings() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return (0, 0);

    final path = result.files.single.path;
    if (path == null) return (0, 0);

    final file = File(path);
    final json = await file.readAsString();
    final data = jsonDecode(json) as Map<String, dynamic>;

    // Import settings
    final settingsList = data['settings'] as List<dynamic>;
    var imported = 0;
    var skipped = 0;

    for (final item in settingsList) {
      try {
        final map = Map<String, dynamic>.from(item as Map);
        map.remove('id'); // Remove ID so it gets a new one
        final setting = AppSetting.fromMap(map);
        await _db.insertSetting(setting);
        imported++;
      } catch (_) {
        skipped++;
      }
    }

    // Import preferences
    if (data.containsKey('preferences')) {
      final prefs = await SharedPreferences.getInstance();
      final prefsMap = Map<String, dynamic>.from(data['preferences'] as Map);
      for (final entry in prefsMap.entries) {
        if (entry.value is bool) {
          await prefs.setBool(entry.key, entry.value as bool);
        }
      }
    }

    return (imported, skipped);
  }
}
