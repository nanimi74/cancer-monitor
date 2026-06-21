import 'dart:io';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdentityService {
  const DeviceIdentityService();

  static const _deviceIdKey = 'local_device_id_v1';

  Future<String> deviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_deviceIdKey);
      if (existing != null && existing.isNotEmpty) return existing;

      final created = _createDeviceId();
      await prefs.setString(_deviceIdKey, created);
      return created;
    } catch (_) {
      return _platformPrefix();
    }
  }

  String _createDeviceId() {
    final random = Random.secure();
    final suffix = List<int>.generate(12, (_) => random.nextInt(256))
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${_platformPrefix()}-$suffix';
  }

  String _platformPrefix() {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'device';
  }
}
