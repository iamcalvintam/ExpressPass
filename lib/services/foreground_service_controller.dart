import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/app_setting.dart';

class ForegroundServiceController {
  static const _channel = MethodChannel('com.expresspass/service');
  static const _eventChannel = EventChannel('com.expresspass/usage_events');

  Future<void> startMonitoring(String packageName, List<AppSetting> settings) async {
    final settingsJson = jsonEncode(
      settings.where((s) => s.enabled).map((s) => s.toMap()).toList(),
    );
    await _channel.invokeMethod('startMonitoring', {
      'packageName': packageName,
      'settingsJson': settingsJson,
    });
  }

  Future<void> stopMonitoring() async {
    await _channel.invokeMethod('stopMonitoring');
  }

  Future<bool> isRunning() async {
    return await _channel.invokeMethod<bool>('isRunning') ?? false;
  }

  Stream<Map<String, dynamic>> get usageEvents {
    return _eventChannel.receiveBroadcastStream().map((event) {
      return Map<String, dynamic>.from(event as Map);
    });
  }
}
