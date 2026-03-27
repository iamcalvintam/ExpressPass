import 'package:flutter/services.dart';

class NotificationService {
  static const _channel = MethodChannel('com.expresspass/notifications');

  Future<void> showApplied(String appLabel, int count) async {
    try {
      await _channel.invokeMethod('showApplied', {
        'appLabel': appLabel,
        'count': count,
      });
    } on PlatformException {
      // Notification failed, non-critical
    }
  }

  Future<void> showReverted(String appLabel, int count) async {
    try {
      await _channel.invokeMethod('showReverted', {
        'appLabel': appLabel,
        'count': count,
      });
    } on PlatformException {
      // Notification failed, non-critical
    }
  }

  Future<void> showManualRevert(int count) async {
    try {
      await _channel.invokeMethod('showManualRevert', {
        'count': count,
      });
    } on PlatformException {
      // Notification failed, non-critical
    }
  }
}
