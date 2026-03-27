enum SettingType { system, secure, global }

class AppSetting {
  final int? id;
  final String packageName;
  final bool enabled;
  final SettingType settingType;
  final String label;
  final String key;
  final String valueOnLaunch;
  final String valueOnRevert;

  const AppSetting({
    this.id,
    required this.packageName,
    this.enabled = true,
    required this.settingType,
    required this.label,
    required this.key,
    required this.valueOnLaunch,
    required this.valueOnRevert,
  });

  AppSetting copyWith({
    int? id,
    String? packageName,
    bool? enabled,
    SettingType? settingType,
    String? label,
    String? key,
    String? valueOnLaunch,
    String? valueOnRevert,
  }) {
    return AppSetting(
      id: id ?? this.id,
      packageName: packageName ?? this.packageName,
      enabled: enabled ?? this.enabled,
      settingType: settingType ?? this.settingType,
      label: label ?? this.label,
      key: key ?? this.key,
      valueOnLaunch: valueOnLaunch ?? this.valueOnLaunch,
      valueOnRevert: valueOnRevert ?? this.valueOnRevert,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'package_name': packageName,
      'enabled': enabled ? 1 : 0,
      'setting_type': settingType.name,
      'label': label,
      'setting_key': key,
      'value_on_launch': valueOnLaunch,
      'value_on_revert': valueOnRevert,
    };
  }

  factory AppSetting.fromMap(Map<String, dynamic> map) {
    return AppSetting(
      id: map['id'] as int?,
      packageName: map['package_name'] as String,
      enabled: (map['enabled'] as int) == 1,
      settingType: SettingType.values.byName(map['setting_type'] as String),
      label: map['label'] as String,
      key: map['setting_key'] as String,
      valueOnLaunch: map['value_on_launch'] as String,
      valueOnRevert: map['value_on_revert'] as String,
    );
  }
}
