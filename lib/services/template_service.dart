import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../database/database_helper.dart';
import '../models/app_setting.dart';
import '../models/setting_template.dart';

class TemplateService {
  final DatabaseHelper _db = DatabaseHelper();
  List<SettingTemplate>? _cachedBuiltIn;

  Future<List<SettingTemplate>> getTemplates() async {
    final builtIn = await _getBuiltInTemplates();
    final custom = await getCustomTemplates();
    return [...custom, ...builtIn];
  }

  Future<List<SettingTemplate>> _getBuiltInTemplates() async {
    if (_cachedBuiltIn != null) return _cachedBuiltIn!;
    final jsonString = await rootBundle.loadString('assets/templates.json');
    final List<dynamic> jsonList = jsonDecode(jsonString);
    _cachedBuiltIn = jsonList.map((json) => SettingTemplate.fromJson(json)).toList();
    return _cachedBuiltIn!;
  }

  Future<List<SettingTemplate>> getCustomTemplates() async {
    final rows = await _db.getCustomTemplates();
    return rows.map((row) => SettingTemplate(
      settingType: SettingType.values.byName(row['setting_type'] as String),
      label: row['label'] as String,
      key: row['setting_key'] as String,
      valueOnLaunch: row['value_on_launch'] as String,
      valueOnRevert: row['value_on_revert'] as String,
      description: row['description'] as String? ?? '',
      category: 'My Templates',
    )).toList();
  }

  Future<void> saveCustomTemplate(AppSetting setting) async {
    await _db.insertCustomTemplate({
      'setting_type': setting.settingType.name,
      'label': setting.label,
      'setting_key': setting.key,
      'value_on_launch': setting.valueOnLaunch,
      'value_on_revert': setting.valueOnRevert,
      'description': '',
      'category': 'Custom',
    });
  }

  Future<void> deleteCustomTemplate(int id) async {
    await _db.deleteCustomTemplate(id);
  }
}
