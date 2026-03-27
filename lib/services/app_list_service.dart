import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../models/installed_app.dart';

class AppListService {
  static const _channel = MethodChannel('com.expresspass/packages');

  Future<List<InstalledApp>> getInstalledApps() async {
    try {
      final result = await _channel.invokeMethod<List>('getInstalledApps');
      return result?.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return InstalledApp(
          packageName: map['packageName'] as String,
          label: map['label'] as String,
          icon: map['icon'] as Uint8List?,
        );
      }).toList() ?? [];
    } on PlatformException {
      return [];
    }
  }

  Future<bool> launchApp(String packageName) async {
    try {
      final result = await _channel.invokeMethod<bool>('launchApp', {
        'packageName': packageName,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
}
