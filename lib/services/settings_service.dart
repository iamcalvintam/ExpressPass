import 'package:flutter/services.dart';
import '../models/app_setting.dart';

enum WriteResult { success, permissionDenied, failed }

class SettingsService {
  static const _channel = MethodChannel('com.expresspass/settings');

  Future<WriteResult> writeSetting(SettingType type, String key, String value) async {
    try {
      final result = await _channel.invokeMethod<bool>('writeSetting', {
        'type': type.name,
        'key': key,
        'value': value,
      });
      return (result ?? false) ? WriteResult.success : WriteResult.failed;
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED' || e.code == 'SecurityException') {
        return WriteResult.permissionDenied;
      }
      return WriteResult.failed;
    }
  }

  Future<String?> readSetting(SettingType type, String key) async {
    try {
      return await _channel.invokeMethod<String>('readSetting', {
        'type': type.name,
        'key': key,
      });
    } on PlatformException {
      return null;
    }
  }

  Future<List<Map<String, String>>> getSettingsList(SettingType type) async {
    try {
      final result = await _channel.invokeMethod<List>('getSettingsList', {
        'type': type.name,
      });
      return result?.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return {
          'name': map['name']?.toString() ?? '',
          'value': map['value']?.toString() ?? '',
        };
      }).toList() ?? [];
    } on PlatformException {
      return [];
    }
  }
}
