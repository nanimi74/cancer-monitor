import 'dart:io';

abstract interface class StepSyncService {
  Future<bool> requestPermission();
  Future<int?> readTodaySteps();
}

class PlatformStepSyncService implements StepSyncService {
  const PlatformStepSyncService();

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
    // TODO: Implement with HealthKit via a Flutter plugin or MethodChannel.
    // Required iOS capability: HealthKit.
    // Required Info.plist usage text: NSHealthShareUsageDescription.
    return false;
  }

  Future<int?> _readHealthKitSteps() async {
    // TODO: Read HKQuantityTypeIdentifierStepCount for the selected date.
    return null;
  }

  Future<bool> _requestHealthConnectPermission() async {
    // TODO: Implement with Android Health Connect permission request.
    // Required permission: android.permission.health.READ_STEPS.
    return false;
  }

  Future<int?> _readHealthConnectSteps() async {
    // TODO: Read StepsRecord for the selected date range.
    return null;
  }
}
