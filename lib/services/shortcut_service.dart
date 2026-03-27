import 'dart:typed_data';
import 'package:flutter/services.dart';

class ShortcutService {
  static const _channel = MethodChannel('com.expresspass/shortcuts');

  Future<bool> requestPinShortcut(String packageName, String label, Uint8List? icon) async {
    try {
      final result = await _channel.invokeMethod<bool>('requestPinShortcut', {
        'packageName': packageName,
        'label': label,
        'icon': icon,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> isSupported() async {
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on PlatformException {
      return false;
    }
  }
}
