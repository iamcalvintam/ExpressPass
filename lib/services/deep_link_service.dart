import 'package:flutter/services.dart';

class DeepLinkService {
  static const _channel = MethodChannel('com.expresspass/deeplink');
  static Function(String packageName)? onDeepLink;

  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'launch') {
        final packageName = call.arguments as String?;
        if (packageName != null && onDeepLink != null) {
          onDeepLink!(packageName);
        }
      }
    });
  }

  static Future<String?> getInitialLink() async {
    try {
      return await _channel.invokeMethod<String>('getInitialLink');
    } on PlatformException {
      return null;
    }
  }
}
