import 'dart:async';

import 'package:flutter/services.dart';

class FilterCamera {
  static const MethodChannel _channel =
      const MethodChannel('filter_camera');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
