import 'dart:io';

import 'package:flutter/services.dart';
import 'package:health/health.dart';

String stepSyncProviderName(TargetPlatform platform) =>
    platform == TargetPlatform.iOS ? 'HealthKit' : 'Health Connect';

abstract interface class StepSyncService {
  Future<bool> requestPermission();
  Future<int?> readTodaySteps();
  Future<bool> openPermissionSettings();
}

class StepSyncPermissionException implements Exception {
  const StepSyncPermissionException(
    this.message, {
    this.issue = StepSyncPermissionIssue.permissionRequired,
  });

  final String message;
  final StepSyncPermissionIssue issue;

  @override
  String toString() => message;
}

enum StepSyncPermissionIssue {
  permissionRequired,
  healthConnectRequired,
}

class PlatformStepSyncService implements StepSyncService {
  PlatformStepSyncService({Health? health}) : _health = health ?? Health();

  static const _healthConnectChannel = MethodChannel(
    'com.nanimi74.hangyeol/health_connect',
  );

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

  @override
  Future<bool> openPermissionSettings() async {
    if (Platform.isAndroid) {
      return _openHealthConnectSettings();
    }
    return false;
  }

  Future<bool> _requestHealthKitPermission() async {
    return _requestStepPermission();
  }

  Future<int?> _readHealthKitSteps() async {
    return _readTodayStepCount();
  }

  Future<bool> _requestHealthConnectPermission() async {
    final isAvailable = await _isHealthConnectAvailable();
    if (!isAvailable) {
      throw const StepSyncPermissionException(
        'Health Connect 설치 또는 업데이트가 필요합니다.',
        issue: StepSyncPermissionIssue.healthConnectRequired,
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

  Future<bool> _openHealthConnectSettings() async {
    final status = await _health.getHealthConnectSdkStatus();
    if (status != HealthConnectSdkStatus.sdkAvailable) {
      return _openNativeHealthConnectTarget('openInstall');
    }

    return _openNativeHealthConnectTarget('openSettings');
  }

  Future<bool> _openNativeHealthConnectTarget(String method) async {
    try {
      return await _healthConnectChannel.invokeMethod<bool>(method) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _requestStepPermission() async {
    await _ensureConfigured();
    final currentPermission = await _health.hasPermissions(
      _stepTypes,
      permissions: _stepPermissions,
    );
    if (currentPermission == true) return true;

    if (Platform.isAndroid) {
      throw const StepSyncPermissionException(
        'Health Connect에서 한결의 걸음수 읽기 권한을 허용해 주세요.',
      );
    }

    final granted = await _health.requestAuthorization(
      _stepTypes,
      permissions: _stepPermissions,
    );
    return granted;
  }

  Future<bool> _isHealthConnectAvailable() async {
    final status = await _health.getHealthConnectSdkStatus();
    if (status == HealthConnectSdkStatus.sdkAvailable) return true;
    return false;
  }

  Future<int?> _readTodayStepCount() async {
    await _ensureConfigured();
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return _health.getTotalStepsInInterval(startOfDay, now);
  }
}
