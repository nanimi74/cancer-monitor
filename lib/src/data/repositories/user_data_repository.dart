import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/medication.dart';
import '../models/symptom_record.dart';
import '../models/user_profile.dart';
import '../models/weight_record.dart';
import 'user_data_paths.dart';

class UserSettings {
  const UserSettings({
    this.notificationEnabled = false,
    this.stepSyncEnabled = false,
  });

  final bool notificationEnabled;
  final bool stepSyncEnabled;
}

class UserDataSnapshot {
  const UserDataSnapshot({
    required this.settings,
    this.profile,
    this.medications = const [],
    this.weights = const [],
    this.symptoms = const [],
  });

  final UserSettings settings;
  final UserProfile? profile;
  final List<Medication> medications;
  final List<WeightRecord> weights;
  final List<SymptomRecord> symptoms;
}

class UserDataRepository {
  UserDataRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  String _cacheKey(String userId, {String? deviceId}) {
    if (deviceId == null || deviceId.isEmpty) {
      return 'user_data_snapshot_v1_$userId';
    }
    return 'user_data_snapshot_v2_${userId}_$deviceId';
  }

  Future<UserDataSnapshot> load(String userId, {String? deviceId}) async {
    final paths = UserDataPaths(userId);
    final userDoc = await _db.doc(paths.userDocument).get();
    final deviceDoc = deviceId == null || deviceId.isEmpty
        ? null
        : await _db.doc(paths.deviceDocument(deviceId)).get();
    final profileDoc = await _db.doc(paths.profileDocument).get();
    final medicationDocs =
        await _db.collection(paths.medicationsCollection).orderBy('id').get();
    final weightDocs =
        await _db.collection(paths.weightsCollection).orderBy('date').get();
    final symptomDocs =
        await _db.collection(paths.symptomsCollection).orderBy('date').get();

    return UserDataSnapshot(
      settings: _settingsFromMap(
        deviceDoc?.data() ?? userDoc.data() ?? const {},
      ),
      profile: profileDoc.exists ? _profileFromMap(profileDoc.data()!) : null,
      medications: medicationDocs.docs
          .map((doc) => _medicationFromMap(doc.data()))
          .toList(growable: false),
      weights: weightDocs.docs
          .map((doc) => _weightFromMap(doc.data(), doc.id))
          .toList(growable: false),
      symptoms: symptomDocs.docs
          .map((doc) => _symptomFromMap(doc.data(), doc.id))
          .toList(growable: false),
    );
  }

  Future<void> saveSettings(
    String userId,
    UserSettings settings, {
    String? deviceId,
  }) async {
    final paths = UserDataPaths(userId);
    final documentPath = deviceId == null || deviceId.isEmpty
        ? paths.userDocument
        : paths.deviceDocument(deviceId);
    await _db.doc(documentPath).set({
      'schemaVersion': 1,
      'notificationEnabled': settings.notificationEnabled,
      'stepSyncEnabled': settings.stepSyncEnabled,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<UserDataSnapshot?> loadCachedSnapshot(
    String userId, {
    String? deviceId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey(userId, deviceId: deviceId)) ??
        prefs.getString(_cacheKey(userId));
    if (raw == null || raw.isEmpty) return null;
    try {
      return _snapshotFromCacheMap(_objectMap(jsonDecode(raw)));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCachedSnapshot(
    String userId,
    UserDataSnapshot snapshot, {
    String? deviceId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey(userId, deviceId: deviceId),
      jsonEncode(_snapshotToCacheMap(snapshot)),
    );
  }

  Future<void> clearCachedSnapshot(String userId, {String? deviceId}) async {
    final prefs = await SharedPreferences.getInstance();
    if (deviceId == null || deviceId.isEmpty) {
      await prefs.remove(_cacheKey(userId));
      return;
    }
    await prefs.remove(_cacheKey(userId, deviceId: deviceId));
  }

  Future<void> saveProfile(String userId, UserProfile profile) async {
    final paths = UserDataPaths(userId);
    final batch = _db.batch();
    batch.set(
      _db.doc(paths.userDocument),
      {
        'schemaVersion': 1,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(_db.doc(paths.profileDocument), {
      'sex': profile.sex,
      'birthDate': _dateKey(profile.birthDate),
      'cancerType': profile.cancerType,
      'stage': profile.stage,
      'diagnosisDate': _dateKey(profile.diagnosisDate),
      'metastasis': profile.metastasis,
      'treatmentType': profile.treatmentType,
      'treatmentStartDate': _dateKey(profile.treatmentStartDate),
      'heightCm': profile.heightCm,
      'extra': profile.extra,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> saveMedications(
    String userId,
    List<Medication> medications,
  ) async {
    final paths = UserDataPaths(userId);
    await _replaceCollection(
      collectionPath: paths.medicationsCollection,
      values: {
        for (final medication in medications)
          medication.id.toString(): _medicationToMap(medication),
      },
    );
  }

  Future<void> saveWeights(String userId, List<WeightRecord> weights) async {
    final paths = UserDataPaths(userId);
    await _replaceCollection(
      collectionPath: paths.weightsCollection,
      values: {
        for (final weight in weights)
          _dateKey(weight.date): {
            'date': _dateKey(weight.date),
            'weightKg': weight.weightKg,
            'updatedAt': FieldValue.serverTimestamp(),
          },
      },
    );
  }

  Future<void> saveSymptoms(String userId, List<SymptomRecord> symptoms) async {
    final paths = UserDataPaths(userId);
    await _replaceCollection(
      collectionPath: paths.symptomsCollection,
      values: {
        for (final symptom in symptoms)
          _dateKey(symptom.date): {
            'date': _dateKey(symptom.date),
            'cycleNo': symptom.cycleNo,
            'cycleDay': symptom.cycleDay,
            'mealAmount': symptom.mealAmount,
            'breakfastMemo': symptom.breakfastMemo,
            'lunchMemo': symptom.lunchMemo,
            'dinnerMemo': symptom.dinnerMemo,
            'extraMealMemo': symptom.extraMealMemo,
            'waterAmount': symptom.waterAmount,
            'steps': symptom.steps,
            'stepsSource': symptom.stepsSource,
            'bowel': symptom.bowel,
            'stoolStatus': symptom.stoolStatus,
            'sideEffects': symptom.sideEffects,
            'note': symptom.note,
            'updatedAt': FieldValue.serverTimestamp(),
          },
      },
    );
  }

  Future<void> deleteUserData(String userId) async {
    await clearCachedSnapshot(userId);
    final paths = UserDataPaths(userId);
    await _deleteCollection(paths.medicationsCollection);
    await _deleteCollection(paths.weightsCollection);
    await _deleteCollection(paths.symptomsCollection);
    await _deleteCollection(paths.analysisCollection);
    await _deleteCollection('${paths.userDocument}/profile');
    await _db.doc(paths.userDocument).delete();
  }

  Future<void> _replaceCollection({
    required String collectionPath,
    required Map<String, Map<String, Object?>> values,
  }) async {
    final collection = _db.collection(collectionPath);
    final snapshot = await collection.get();
    final staleDocs =
        snapshot.docs.where((doc) => !values.containsKey(doc.id)).toList();
    if (values.isEmpty && staleDocs.isEmpty) return;

    final batch = _db.batch();

    for (final entry in values.entries) {
      batch.set(collection.doc(entry.key), entry.value);
    }
    for (final doc in staleDocs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  Future<void> _deleteCollection(String collectionPath) async {
    final collection = _db.collection(collectionPath);
    while (true) {
      final snapshot = await collection.limit(200).get();
      if (snapshot.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  static UserSettings _settingsFromMap(Map<String, Object?> data) {
    return UserSettings(
      notificationEnabled: data['notificationEnabled'] == true,
      stepSyncEnabled: data['stepSyncEnabled'] == true,
    );
  }

  static Map<String, Object?> _snapshotToCacheMap(UserDataSnapshot snapshot) {
    return {
      'settings': {
        'notificationEnabled': snapshot.settings.notificationEnabled,
        'stepSyncEnabled': snapshot.settings.stepSyncEnabled,
      },
      'profile': snapshot.profile == null
          ? null
          : _profileToCacheMap(snapshot.profile!),
      'medications': [
        for (final medication in snapshot.medications)
          _medicationToCacheMap(medication),
      ],
      'weights': [
        for (final weight in snapshot.weights) _weightToCacheMap(weight),
      ],
      'symptoms': [
        for (final symptom in snapshot.symptoms) _symptomToCacheMap(symptom),
      ],
    };
  }

  static UserDataSnapshot _snapshotFromCacheMap(Map<String, Object?> data) {
    return UserDataSnapshot(
      settings: _settingsFromMap(_objectMap(data['settings'])),
      profile: data['profile'] == null
          ? null
          : _profileFromMap(_objectMap(data['profile'])),
      medications: _objectMapList(data['medications'])
          .map(_medicationFromMap)
          .toList(growable: false),
      weights: _objectMapList(data['weights'])
          .map((item) => _weightFromMap(item, _string(item['date'])))
          .toList(growable: false),
      symptoms: _objectMapList(data['symptoms'])
          .map((item) => _symptomFromMap(item, _string(item['date'])))
          .toList(growable: false),
    );
  }

  static Map<String, Object?> _profileToCacheMap(UserProfile profile) {
    return {
      'sex': profile.sex,
      'birthDate': _dateKey(profile.birthDate),
      'cancerType': profile.cancerType,
      'stage': profile.stage,
      'diagnosisDate': _dateKey(profile.diagnosisDate),
      'metastasis': profile.metastasis,
      'treatmentType': profile.treatmentType,
      'treatmentStartDate': _dateKey(profile.treatmentStartDate),
      'heightCm': profile.heightCm,
      'extra': profile.extra,
    };
  }

  static Map<String, Object?> _medicationToCacheMap(Medication medication) {
    return {
      'id': medication.id,
      'name': medication.name,
      'dose': medication.dose,
      'frequency': medication.frequency,
      'weekdays': medication.weekdays,
      'reminderEnabled': medication.reminderEnabled,
      'reminders': [
        for (final reminder in medication.reminders)
          {
            'label': reminder.label,
            'time': reminder.time,
            'enabled': reminder.enabled,
          },
      ],
      'memo': medication.memo,
    };
  }

  static Map<String, Object?> _weightToCacheMap(WeightRecord weight) {
    return {
      'date': _dateKey(weight.date),
      'weightKg': weight.weightKg,
    };
  }

  static Map<String, Object?> _symptomToCacheMap(SymptomRecord symptom) {
    return {
      'date': _dateKey(symptom.date),
      'cycleNo': symptom.cycleNo,
      'cycleDay': symptom.cycleDay,
      'mealAmount': symptom.mealAmount,
      'breakfastMemo': symptom.breakfastMemo,
      'lunchMemo': symptom.lunchMemo,
      'dinnerMemo': symptom.dinnerMemo,
      'extraMealMemo': symptom.extraMealMemo,
      'waterAmount': symptom.waterAmount,
      'steps': symptom.steps,
      'stepsSource': symptom.stepsSource,
      'bowel': symptom.bowel,
      'stoolStatus': symptom.stoolStatus,
      'sideEffects': symptom.sideEffects,
      'note': symptom.note,
    };
  }

  static UserProfile _profileFromMap(Map<String, Object?> data) {
    return UserProfile(
      sex: _string(data['sex']),
      birthDate: _date(data['birthDate']),
      cancerType: _string(data['cancerType']),
      stage: _string(data['stage']),
      diagnosisDate: _date(data['diagnosisDate']),
      metastasis: _string(data['metastasis']),
      treatmentType: _string(data['treatmentType']),
      treatmentStartDate: _date(data['treatmentStartDate']),
      heightCm: _double(data['heightCm']),
      extra: _string(data['extra']),
    );
  }

  static Medication _medicationFromMap(Map<String, Object?> data) {
    final reminders = (data['reminders'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (value) => MedicationReminder(
            label: _string(value['label']),
            time: _string(value['time']),
            enabled: value['enabled'] == true,
          ),
        )
        .toList(growable: false);

    return Medication(
      id: _int(data['id']),
      name: _string(data['name']),
      dose: _string(data['dose']),
      frequency: _string(data['frequency']),
      weekdays: _stringList(data['weekdays']),
      reminderEnabled: data['reminderEnabled'] == true,
      reminders: reminders,
      memo: _string(data['memo']),
    );
  }

  static Map<String, Object?> _medicationToMap(Medication medication) {
    return {
      'id': medication.id,
      'name': medication.name,
      'dose': medication.dose,
      'frequency': medication.frequency,
      'weekdays': medication.weekdays,
      'reminderEnabled': medication.reminderEnabled,
      'reminders': [
        for (final reminder in medication.reminders)
          {
            'label': reminder.label,
            'time': reminder.time,
            'enabled': reminder.enabled,
          },
      ],
      'memo': medication.memo,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static WeightRecord _weightFromMap(
    Map<String, Object?> data,
    String fallbackDateKey,
  ) {
    return WeightRecord(
      date: _date(data['date'] ?? fallbackDateKey),
      weightKg: _double(data['weightKg']),
    );
  }

  static SymptomRecord _symptomFromMap(
    Map<String, Object?> data,
    String fallbackDateKey,
  ) {
    return SymptomRecord(
      date: _date(data['date'] ?? fallbackDateKey),
      cycleNo: _int(data['cycleNo']),
      cycleDay: _int(data['cycleDay']),
      mealAmount: _string(data['mealAmount']),
      breakfastMemo: _string(data['breakfastMemo']),
      lunchMemo: _string(data['lunchMemo']),
      dinnerMemo: _string(data['dinnerMemo']),
      extraMealMemo: _string(data['extraMealMemo']),
      waterAmount: _string(data['waterAmount']),
      steps: _int(data['steps']),
      stepsSource: _string(data['stepsSource'], fallback: '수동'),
      bowel: _string(data['bowel']),
      stoolStatus: _string(data['stoolStatus']),
      sideEffects: _stringList(data['sideEffects']),
      note: _string(data['note']),
    );
  }

  static String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static DateTime _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  static String _string(Object? value, {String fallback = ''}) {
    if (value is String) return value;
    return fallback;
  }

  static List<String> _stringList(Object? value) {
    return (value as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(growable: false);
  }

  static Map<String, Object?> _objectMap(Object? value) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  static List<Map<String, Object?>> _objectMapList(Object? value) {
    return (value as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(_objectMap)
        .toList(growable: false);
  }

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _double(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
