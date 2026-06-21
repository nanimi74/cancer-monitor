class UserDataPaths {
  const UserDataPaths(this.userId);

  final String userId;

  String get userDocument => 'users/$userId';

  String get profileDocument => '$userDocument/profile/main';

  String deviceDocument(String deviceId) => '$userDocument/devices/$deviceId';

  String get medicationsCollection => '$userDocument/medications';

  String medicationDocument(String medicationId) =>
      '$medicationsCollection/$medicationId';

  String get weightsCollection => '$userDocument/weights';

  String weightDocument(String dateKey) => '$weightsCollection/$dateKey';

  String get symptomsCollection => '$userDocument/symptoms';

  String symptomDocument(String dateKey) => '$symptomsCollection/$dateKey';

  String get analysisCollection => '$userDocument/analysis';

  String analysisDocument(String cycleKey) => '$analysisCollection/$cycleKey';
}
