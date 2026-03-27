import 'package:flutter/services.dart';

class PermissionService {
  static const _channel = MethodChannel('com.expresspass/permissions');

  Future<bool> hasWriteSecureSettings() async {
    try {
      return await _channel.invokeMethod<bool>('hasWriteSecureSettings') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> hasUsageStatsPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasUsageStatsPermission') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> requestUsageStatsPermission() async {
    try {
      await _channel.invokeMethod('requestUsageStatsPermission');
    } on PlatformException {
      // Ignored
    }
  }

  Future<bool> hasNotificationPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasNotificationPermission') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> requestNotificationPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestNotificationPermission') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> openNotificationSettings() async {
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } on PlatformException {
      // Ignored
    }
  }

  Future<String> getAdbCommand() async {
    try {
      return await _channel.invokeMethod<String>('getAdbCommand') ?? '';
    } on PlatformException {
      return '';
    }
  }
}
