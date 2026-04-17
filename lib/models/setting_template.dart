import 'app_setting.dart';

class SettingTemplate {
  final SettingType settingType;
  final String label;
  final String key;
  final String valueOnLaunch;
  final String valueOnRevert;
  final String description;
  final String category;

  const SettingTemplate({
    required this.settingType,
    required this.label,
    required this.key,
    required this.valueOnLaunch,
    required this.valueOnRevert,
    this.description = '',
    this.category = 'Misc',
  });

  factory SettingTemplate.fromJson(Map<String, dynamic> json) {
    return SettingTemplate(
      settingType: SettingType.values.byName(json['settingType'] as String),
      label: json['label'] as String,
      key: json['key'] as String,
      valueOnLaunch: json['valueOnLaunch'] as String,
      valueOnRevert: json['valueOnRevert'] as String,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'Misc',
    );
  }

  AppSetting toAppSetting(String packageName) {
    return AppSetting(
      packageName: packageName,
      settingType: settingType,
      label: label,
      key: key,
      valueOnLaunch: valueOnLaunch,
      valueOnRevert: valueOnRevert,
    );
  }
}
