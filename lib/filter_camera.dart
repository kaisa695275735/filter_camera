import 'dart:async';

import 'package:flutter/services.dart';

class FilterCamera {
  static const MethodChannel _channel =
      const MethodChannel('filter_camera');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static Future<int> startPreview() async{
    int response = await _channel.invokeMethod('start_preview');
    return response;
  }

  static Future<bool> stopPreview() async{
    bool response = await _channel.invokeMethod('stop_preview');
    return response;
  }
}
