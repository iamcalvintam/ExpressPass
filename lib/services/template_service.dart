import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/setting_template.dart';

class TemplateService {
  List<SettingTemplate>? _cachedTemplates;

  Future<List<SettingTemplate>> getTemplates() async {
    if (_cachedTemplates != null) return _cachedTemplates!;
    final jsonString = await rootBundle.loadString('assets/templates.json');
    final List<dynamic> jsonList = jsonDecode(jsonString);
    _cachedTemplates = jsonList.map((json) => SettingTemplate.fromJson(json)).toList();
    return _cachedTemplates!;
  }
}
