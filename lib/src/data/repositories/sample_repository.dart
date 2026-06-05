import '../models/medication.dart';
import '../models/symptom_record.dart';
import '../models/user_profile.dart';
import '../models/weight_record.dart';

class SampleRepository {
  const SampleRepository();

  UserProfile get profile => UserProfile(
        sex: '여성',
        birthDate: DateTime(1973, 8, 12),
        cancerType: '유방암',
        stage: '2기',
        heightCm: 162,
      );

  List<Medication> get medications => const [
        Medication(
          name: '항구토제',
          dose: '1정',
          frequency: '매일',
          memo: '식후 복용',
          reminders: [
            MedicationReminder(label: '아침식후', time: '08:30', enabled: true),
            MedicationReminder(label: '점심식후', time: '13:00', enabled: true),
            MedicationReminder(label: '저녁식후', time: '19:00', enabled: false),
          ],
        ),
      ];

  List<WeightRecord> get weights => [
        WeightRecord(date: DateTime(2026, 6, 1), weightKg: 50.6),
        WeightRecord(date: DateTime(2026, 6, 2), weightKg: 51.0),
      ];

  List<SymptomRecord> get symptoms => [
        SymptomRecord(
          date: DateTime(2026, 6, 1),
          cycleNo: 2,
          cycleDay: 1,
          mealAmount: '평소와같음',
          waterAmount: '1~1.5L',
          steps: 1500,
          bowel: '있음',
          stoolStatus: '딱딱한변',
          sideEffects: ['오심', '피로', '식욕저하'],
          note: '점점 좋아지고 있음 맘이 아플뿐',
        ),
        SymptomRecord(
          date: DateTime(2026, 6, 2),
          cycleNo: 2,
          cycleDay: 2,
          mealAmount: '평소와같음',
          waterAmount: '1~1.5L',
          steps: 1500,
          bowel: '있음',
          stoolStatus: '딱딱한변',
          sideEffects: ['없음'],
        ),
      ];
}
