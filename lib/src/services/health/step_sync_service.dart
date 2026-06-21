import 'dart:io';

import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

abstract interface class StepSyncService {
  Future<bool> requestPermission();
  Future<int?> readTodaySteps();
}

class StepSyncPermissionException implements Exception {
  const StepSyncPermissionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PlatformStepSyncService implements StepSyncService {
  PlatformStepSyncService({Health? health}) : _health = health ?? Health();

  final Health _health;
  var _configured = false;

  static const _stepTypes = [HealthDataType.STEPS];
  static const _stepPermissions = [HealthDataAccess.READ];

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  Future<bool> requestPermission() async {
    if (Platform.isIOS) {
      return _requestHealthKitPermission();
    }
    if (Platform.isAndroid) {
      return _requestHealthConnectPermission();
    }
    return false;
  }

  @override
  Future<int?> readTodaySteps() async {
    if (Platform.isIOS) {
      return _readHealthKitSteps();
    }
    if (Platform.isAndroid) {
      return _readHealthConnectSteps();
    }
    return null;
  }

  Future<bool> _requestHealthKitPermission() async {
    return _requestStepPermission();
  }

  Future<int?> _readHealthKitSteps() async {
    return _readTodayStepCount();
  }

  Future<bool> _requestHealthConnectPermission() async {
    final activityPermission = await Permission.activityRecognition.request();
    if (!activityPermission.isGranted) {
      throw const StepSyncPermissionException(
        'Android 설정에서 항암기록관리의 신체 활동 권한을 허용해 주세요.',
      );
    }

    final isAvailable =
        await _isHealthConnectAvailable(openInstallIfNeeded: true);
    if (!isAvailable) {
      throw const StepSyncPermissionException(
        'Health Connect를 설치/업데이트한 뒤, Health Connect에서 항암기록관리의 걸음수 읽기를 허용해 주세요.',
      );
    }

    return _requestStepPermission();
  }

  Future<int?> _readHealthConnectSteps() async {
    final isAvailable = await _isHealthConnectAvailable();
    if (!isAvailable) return null;

    await _ensureConfigured();
    final hasPermission = await _health.hasPermissions(
      _stepTypes,
      permissions: _stepPermissions,
    );
    if (hasPermission != true) return null;

    return _readTodayStepCount();
  }

  Future<bool> _requestStepPermission() async {
    await _ensureConfigured();
    final currentPermission = await _health.hasPermissions(
      _stepTypes,
      permissions: _stepPermissions,
    );
    if (currentPermission == true) return true;

    final granted = await _health.requestAuthorization(
      _stepTypes,
      permissions: _stepPermissions,
    );
    if (!granted && Platform.isAndroid) {
      throw const StepSyncPermissionException(
        'Health Connect에서 항암기록관리의 걸음수 읽기 권한을 허용해 주세요.',
      );
    }
    return granted;
  }

  Future<bool> _isHealthConnectAvailable({
    bool openInstallIfNeeded = false,
  }) async {
    final status = await _health.getHealthConnectSdkStatus();
    if (status == HealthConnectSdkStatus.sdkAvailable) return true;
    if (openInstallIfNeeded &&
        status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
      await _health.installHealthConnect();
    }
    return false;
  }

  Future<int?> _readTodayStepCount() async {
    await _ensureConfigured();
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return _health.getTotalStepsInInterval(startOfDay, now);
  }
}
