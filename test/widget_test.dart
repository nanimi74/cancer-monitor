import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cancer_monitor/src/app/cancer_monitor_app.dart';
import 'package:cancer_monitor/src/features/home_shell.dart';
import 'package:cancer_monitor/src/features/medication/medication_screen.dart';
import 'package:cancer_monitor/src/features/symptom/symptom_screen.dart';
import 'package:cancer_monitor/src/features/weight/weight_screen.dart';
import 'package:cancer_monitor/src/data/models/medication.dart';
import 'package:cancer_monitor/src/data/models/user_profile.dart';
import 'package:cancer_monitor/src/data/models/weight_record.dart';
import 'package:cancer_monitor/src/data/repositories/user_data_repository.dart';
import 'package:cancer_monitor/src/services/health/step_sync_service.dart';
import 'package:cancer_monitor/src/services/notifications/notification_permission_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('starts from entry screen and opens preview shell',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CancerMonitorApp());

    expect(find.text('항암 치료 기록을\n가볍게 남기고 정리해요.'), findsOneWidget);
    expect(find.text('로그인하고 시작하기'), findsOneWidget);
    expect(find.text('둘러보기'), findsOneWidget);

    await tester.tap(find.text('둘러보기'));
    await tester.pumpAndSettle();

    expect(find.text('마이페이지'), findsWidgets);
    expect(find.text('복약관리'), findsOneWidget);
    expect(find.text('체중관리'), findsOneWidget);
    expect(find.text('증상관리'), findsOneWidget);
    expect(find.text('AI분석'), findsOneWidget);

    final exitPreviewButton = find.widgetWithText(OutlinedButton, '둘러보기 나가기');
    await tester.scrollUntilVisible(exitPreviewButton, 350);
    await tester.tap(exitPreviewButton);
    await tester.pumpAndSettle();

    expect(find.text('로그인하고 시작하기'), findsOneWidget);
  });

  testWidgets('opens login screen and signs in with email',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CancerMonitorApp());

    await tester.tap(find.text('로그인하고 시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('로그인'), findsOneWidget);
    expect(find.text('회원 전용 서비스입니다.\n비회원의 경우 가입 후 이용해주세요.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'patient@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text('이메일로 로그인/가입'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('마이페이지'), findsWidgets);
    expect(find.text('복약관리'), findsOneWidget);
    expect(find.text('체중관리'), findsOneWidget);
    expect(find.text('증상관리'), findsOneWidget);
    expect(find.text('AI분석'), findsOneWidget);
  });

  testWidgets('signs out from profile and returns to entry screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CancerMonitorApp());

    await tester.tap(find.text('로그인하고 시작하기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'patient@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text('이메일로 로그인/가입'));
    await tester.pumpAndSettle();

    final signOutButton = find.widgetWithText(OutlinedButton, '로그아웃');
    await tester.scrollUntilVisible(
      signOutButton,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(signOutButton);
    await tester.pumpAndSettle();

    expect(find.text('로그인하고 시작하기'), findsOneWidget);
    expect(find.text('둘러보기'), findsOneWidget);
  });

  testWidgets('deletes account from profile and returns to entry screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CancerMonitorApp());

    await tester.tap(find.text('로그인하고 시작하기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'patient@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text('이메일로 로그인/가입'));
    await tester.pumpAndSettle();

    final deleteButton = find.widgetWithText(OutlinedButton, '회원탈퇴');
    await tester.scrollUntilVisible(deleteButton, 350);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(find.text('회원탈퇴'), findsWidgets);
    await tester.tap(find.text('탈퇴하기'));
    await tester.pumpAndSettle();

    expect(find.text('로그인하고 시작하기'), findsOneWidget);
    expect(find.text('둘러보기'), findsOneWidget);
  });

  testWidgets('preview profile blocks user info access and shows exit action',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeShell(isPreview: true, hasRequiredInfo: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('사용자정보를 입력해 주세요'), findsOneWidget);
    expect(find.text('사용자 정보'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('profile-info-menu')));
    await tester.tap(find.byKey(const ValueKey('profile-info-menu')));
    await tester.pumpAndSettle();

    expect(find.text('회원만 이용할 수 있습니다.'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('저장'), findsNothing);

    final exitPreviewButton = find.widgetWithText(OutlinedButton, '둘러보기 나가기');
    await tester.scrollUntilVisible(exitPreviewButton, 350);
    await tester.pumpAndSettle();

    expect(exitPreviewButton, findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '로그아웃'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, '회원탈퇴'), findsNothing);
  });

  testWidgets('medication notification opens symptom tab',
      (WidgetTester tester) async {
    final notificationService = _FakeNotificationPermissionService();
    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          hasRequiredInfo: true,
          notificationPermissionService: notificationService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('복약관리'));
    await tester.pumpAndSettle();

    expect(find.text('약물 관리'), findsOneWidget);

    notificationService.emitPayload('medication:123');
    await tester.pumpAndSettle();

    expect(find.text('증상 관리'), findsOneWidget);
  });

  testWidgets('medication add is disabled until required profile exists',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MedicationScreen(hasRequiredInfo: false),
        ),
      ),
    );

    expect(find.text('약물 관리'), findsOneWidget);
    expect(find.text('등록된 약물이 없습니다.'), findsOneWidget);
    expect(find.textContaining('사용자정보를 입력해 주세요'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, '약물 등록'));
    await tester.pumpAndSettle();

    expect(find.text('약물 등록'), findsOneWidget);
  });

  testWidgets('weight input is blocked until required profile exists',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WeightScreen(hasRequiredInfo: false),
        ),
      ),
    );

    expect(find.text('체중 관리'), findsOneWidget);
    expect(find.textContaining('사용자정보를 입력해 주세요'), findsOneWidget);
    expect(find.textContaining('현재 BMI'), findsNothing);

    final todayCell = find.byKey(ValueKey('weight-day-${_testFormatDate()}'));
    await tester.ensureVisible(todayCell);
    await tester.tap(todayCell);
    await tester.pumpAndSettle();

    expect(find.text('마이페이지의 사용자정보를 입력하세요.'), findsOneWidget);
    expect(find.text('체중(kg)'), findsNothing);
  });

  testWidgets('weight record shows bmi and chart after input',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WeightScreen(heightCm: 162),
        ),
      ),
    );

    expect(find.textContaining('현재 BMI'), findsNothing);

    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    final todayCell =
        find.byKey(ValueKey('weight-day-${_testFormatDate(today)}'));
    final tomorrowCell =
        find.byKey(ValueKey('weight-day-${_testFormatDate(tomorrow)}'));

    await tester.scrollUntilVisible(
      todayCell,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(todayCell);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '51.0');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.textContaining('현재 BMI'), findsOneWidget);
    expect(find.textContaining('최근 체중 51.0kg'), findsOneWidget);
    expect(find.text('51.0kg'), findsWidgets);

    await tester.scrollUntilVisible(
      tomorrowCell,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(tomorrowCell);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '50.5');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.textContaining('최근 체중 50.5kg'), findsOneWidget);
    expect(find.text('50.5kg'), findsWidgets);
    expect(find.textContaining('그래프를 그릴 체중 기록이 부족합니다'), findsNothing);
  });

  testWidgets('weight screen places bmi banner above calendar',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeightScreen(
            heightCm: 162,
            initialRecords: [
              WeightRecord(date: DateTime(2026, 6, 2), weightKg: 59.8),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bmiTop = tester.getTopLeft(find.textContaining('현재 BMI')).dy;
    final calendarTop = tester
        .getTopLeft(
          find.text('${DateTime.now().year}년 ${DateTime.now().month}월'),
        )
        .dy;

    expect(bmiTop, lessThan(calendarTop));
  });

  testWidgets('rapid weight gain shows consultation advice',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WeightScreen(heightCm: 162),
        ),
      ),
    );

    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    final todayCell =
        find.byKey(ValueKey('weight-day-${_testFormatDate(today)}'));
    final tomorrowCell =
        find.byKey(ValueKey('weight-day-${_testFormatDate(tomorrow)}'));

    await tester.scrollUntilVisible(
      todayCell,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(todayCell);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '50.0');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      tomorrowCell,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(tomorrowCell);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '52.0');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('🚨 체중 변화 상담 권고'), findsOneWidget);
    expect(find.textContaining('증가가 확인됩니다'), findsOneWidget);
    expect(find.textContaining('부종, 복부팽만, 숨참'), findsOneWidget);
  });

  testWidgets('symptom input is blocked until required profile exists',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SymptomScreen(hasRequiredInfo: false),
        ),
      ),
    );

    await tester.tap(find.byKey(ValueKey('symptom-day-${_testFormatDate()}')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(ElevatedButton, '증상기록하기'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final writeButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '증상기록하기'),
    );
    await tester.pumpAndSettle();

    expect(writeButton.onPressed, isNull);
    expect(find.text('증상 기록'), findsNothing);
  });

  testWidgets('symptom record can be added and shown in calendar',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SymptomScreen(
            stepSyncService: _FakeStepSyncService(),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(ValueKey('symptom-day-${_testFormatDate()}')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(ElevatedButton, '증상기록하기'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    tester
        .widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, '증상기록하기'),
        )
        .onPressed
        ?.call();
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '2');
    await tester.enterText(find.byType(TextFormField).at(1), '2');
    await tester.tap(find.text('선택').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('평소와 같음'));
    await tester.pumpAndSettle();

    await tester.drag(_symptomEditorScrollable, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('선택').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('1~1.5L'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('symptom-steps-field')),
      220,
      scrollable: _symptomEditorScrollable,
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('symptom-steps-field')),
      '1500',
    );

    await tester.drag(_symptomEditorScrollable, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('있음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('딱딱한변'));
    await tester.pumpAndSettle();

    await tester.drag(_symptomEditorScrollable, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('오심'),
      220,
      scrollable: _symptomEditorScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('오심'));
    await tester.scrollUntilVisible(
      find.text('피로'),
      220,
      scrollable: _symptomEditorScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('피로'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('2-2'), findsWidgets);
    expect(find.text('평소와 같음'), findsOneWidget);
    expect(find.text('1~1.5L'), findsOneWidget);
    expect(find.text('1500보'), findsOneWidget);
    expect(find.text('오심'), findsWidgets);
    expect(find.text('피로'), findsWidgets);
  });

  testWidgets('linked symptom steps can be saved while empty',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SymptomScreen(
            stepSyncEnabled: true,
            stepSyncService: _NullStepSyncService(),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(ValueKey('symptom-day-${_testFormatDate()}')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(ElevatedButton, '증상기록하기'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    tester
        .widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, '증상기록하기'),
        )
        .onPressed
        ?.call();
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '2');
    await tester.enterText(find.byType(TextFormField).at(1), '2');
    await tester.tap(find.text('선택').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('평소와 같음'));
    await tester.pumpAndSettle();

    await tester.drag(_symptomEditorScrollable, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('선택').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('1~1.5L'));
    await tester.pumpAndSettle();

    await tester.drag(_symptomEditorScrollable, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('있음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('딱딱한변'));
    await tester.pumpAndSettle();

    await tester.drag(_symptomEditorScrollable, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('오심'),
      220,
      scrollable: _symptomEditorScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('오심'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('2-2'), findsWidgets);
    expect(find.text('0보'), findsOneWidget);
    expect(find.text('운동량을 입력해주세요.'), findsNothing);
  });

  testWidgets('medication can be added with multiple default reminders',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MedicationScreen(
            notificationEnabled: true,
            notificationPermissionService: _FakeNotificationPermissionService(),
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(ElevatedButton, '약물 등록'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '항구토제');
    await tester.enterText(find.byType(TextFormField).at(1), '1정');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('항구토제'), findsOneWidget);
    expect(find.textContaining('아침식후 09:00'), findsOneWidget);
    expect(find.textContaining('점심식후 13:00'), findsOneWidget);
    expect(find.textContaining('저녁식후 19:00'), findsOneWidget);
    expect(find.textContaining('1정'), findsOneWidget);
    expect(find.text('켜짐'), findsOneWidget);
  });

  testWidgets('medication list is kept after switching bottom tabs',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          hasRequiredInfo: true,
          notificationPermissionService: _FakeNotificationPermissionService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('복약관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '약물 등록'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '항구토제');
    await tester.enterText(find.byType(TextFormField).at(1), '1정');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('항구토제'), findsOneWidget);
    expect(find.text('꺼짐'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.tap(find.text('마이페이지'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('복약관리'));
    await tester.pumpAndSettle();

    expect(find.text('항구토제'), findsOneWidget);
  });

  testWidgets('medication notification opens symptom tab',
      (WidgetTester tester) async {
    final notificationService = _FakeNotificationPermissionService();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          hasRequiredInfo: true,
          notificationPermissionService: notificationService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('복약관리'));
    await tester.pumpAndSettle();

    expect(find.text('약물 관리'), findsOneWidget);

    notificationService.emitPayload('medication:1');
    await tester.pumpAndSettle();

    expect(find.text('증상 관리'), findsOneWidget);
  });

  testWidgets('medication save with reminder shows only reminder toast',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          hasRequiredInfo: true,
          notificationPermissionService: _FakeNotificationPermissionService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('마이페이지'));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('notification-permission-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('허용'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('복약관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '약물 등록'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '항구토제');
    await tester.enterText(find.byType(TextFormField).at(1), '1정');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('약물 정보가 저장되었습니다.'), findsNothing);
    expect(find.text('복약 알림이 등록되었습니다.'), findsOneWidget);
  });

  testWidgets('profile notification toggle only cancels this device reminders',
      (WidgetTester tester) async {
    final notificationService = _FakeNotificationPermissionService();
    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          hasRequiredInfo: true,
          notificationPermissionService: notificationService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('복약관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '약물 등록'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '항구토제');
    await tester.enterText(find.byType(TextFormField).at(1), '1정');
    await tester.tap(find.byKey(const ValueKey('medication-reminder-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('허용'));
    await tester.pumpAndSettle();

    expect(find.text('켜짐'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.tap(find.text('마이페이지'));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('notification-permission-switch')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.tap(find.text('복약관리'));
    await tester.pumpAndSettle();

    expect(find.text('항구토제'), findsOneWidget);
    expect(find.text('꺼짐'), findsOneWidget);
    expect(find.text('켜짐'), findsNothing);
    expect(notificationService.syncedMedicationBatches.last, isEmpty);

    await tester.tap(find.text('마이페이지'));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('notification-permission-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('허용'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.tap(find.text('복약관리'));
    await tester.pumpAndSettle();

    expect(find.text('항구토제'), findsOneWidget);
    expect(find.text('켜짐'), findsOneWidget);
    expect(
        notificationService.syncedMedicationBatches.last.single.name, '항구토제');
  });

  testWidgets('medication defaults to notification setting without enabling it',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          hasRequiredInfo: true,
          notificationPermissionService: _FakeNotificationPermissionService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('복약관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '약물 등록'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '항구토제');
    await tester.enterText(find.byType(TextFormField).at(1), '1정');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('항구토제'), findsOneWidget);
    expect(find.text('꺼짐'), findsOneWidget);
    expect(find.text('켜짐'), findsNothing);
    expect(find.text('알림 권한'), findsNothing);
  });

  testWidgets('home shell shows loading message until user data is loaded',
      (WidgetTester tester) async {
    final repository = _DelayedLoadUserDataRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          hasRequiredInfo: false,
          userId: 'user-1',
          userDataRepository: repository,
          notificationPermissionService: _FakeNotificationPermissionService(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('사용자 데이터를 불러오고 있어요.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('복약관리'), findsNothing);

    repository.completeLoad();
    await tester.pumpAndSettle();

    expect(find.text('사용자 데이터를 불러오고 있어요.'), findsNothing);
    expect(find.text('복약관리'), findsOneWidget);
    await tester.tap(find.text('마이페이지').last);
    await tester.pumpAndSettle();

    expect(find.text('사용자 정보 요약'), findsOneWidget);
    expect(find.text('유방암 · 2기'), findsOneWidget);
  });

  testWidgets(
      'home shell starts empty without error toast when no cache exists',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          hasRequiredInfo: false,
          userId: 'new-user',
          userDataRepository: _FailingLoadUserDataRepository(),
          notificationPermissionService: _FakeNotificationPermissionService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('저장된 기록을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.'), findsNothing);
    expect(find.text('마이페이지'), findsWidgets);
    expect(find.text('사용자 정보'), findsOneWidget);
  });

  testWidgets('home shell restores cached medication records when remote fails',
      (WidgetTester tester) async {
    final repository = _CachedMedicationUserDataRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          hasRequiredInfo: false,
          userId: 'user-1',
          userDataRepository: repository,
          notificationPermissionService: _FakeNotificationPermissionService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('복약관리'));
    await tester.pumpAndSettle();

    expect(find.text('항구토제'), findsOneWidget);
    expect(find.text('등록된 약물이 없습니다.'), findsNothing);
  });

  testWidgets('home shell prefers remote records over stale cache',
      (WidgetTester tester) async {
    final repository = _RemoteMedicationWithStaleCacheRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          hasRequiredInfo: false,
          userId: 'user-1',
          userDataRepository: repository,
          notificationPermissionService: _FakeNotificationPermissionService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('복약관리'));
    await tester.pumpAndSettle();

    expect(find.text('서버약'), findsOneWidget);
    expect(find.text('캐시약'), findsNothing);
    expect(repository.cachedSnapshotSaved, isTrue);
  });

  testWidgets('home shell keeps notification setting scoped to device',
      (WidgetTester tester) async {
    final repository = _DeviceScopedSettingsRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          hasRequiredInfo: false,
          userId: 'user-1',
          deviceId: 'ios-device',
          userDataRepository: repository,
          notificationPermissionService: _FakeNotificationPermissionService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('마이페이지').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('notification-permission-switch')),
        findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('notification-permission-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('허용'));
    await tester.pumpAndSettle();

    expect(repository.savedDeviceId, 'ios-device');
    expect(repository.savedSettings?.notificationEnabled, isTrue);
  });

  testWidgets('home shell reads different settings for each device',
      (WidgetTester tester) async {
    final repository = _DeviceScopedSettingsRepository(
      settingsByDevice: const {
        'ios-device': UserSettings(notificationEnabled: true),
        'android-device': UserSettings(notificationEnabled: false),
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          hasRequiredInfo: false,
          userId: 'user-1',
          deviceId: 'ios-device',
          userDataRepository: repository,
          notificationPermissionService: _FakeNotificationPermissionService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('복약관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '약물 등록'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '아이폰약');
    await tester.enterText(find.byType(TextFormField).at(1), '1정');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(repository.savedMedications.last.reminderEnabled, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          hasRequiredInfo: false,
          userId: 'user-1',
          deviceId: 'android-device',
          userDataRepository: repository,
          notificationPermissionService: _FakeNotificationPermissionService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('복약관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '약물 등록'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '안드로이드약');
    await tester.enterText(find.byType(TextFormField).at(1), '1정');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(repository.savedMedications.last.reminderEnabled, isFalse);
  });

  testWidgets('home shell scopes medication reminder toggles to device',
      (WidgetTester tester) async {
    final repository = _DeviceScopedSettingsRepository(
      settingsByDevice: const {
        'ios-device': UserSettings(
          notificationEnabled: true,
          medicationReminderEnabled: {101: true},
        ),
        'android-device': UserSettings(
          notificationEnabled: false,
          medicationReminderEnabled: {101: false},
        ),
      },
      medications: const [
        Medication(
          id: 101,
          name: '공통약',
          dose: '1정',
          frequency: '매일',
          weekdays: [],
          reminderEnabled: true,
          reminders: [
            MedicationReminder(label: '아침식후', time: '09:00', enabled: true),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          hasRequiredInfo: false,
          userId: 'user-1',
          deviceId: 'android-device',
          userDataRepository: repository,
          notificationPermissionService: _FakeNotificationPermissionService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('복약관리'));
    await tester.pumpAndSettle();

    expect(find.text('공통약'), findsOneWidget);
    expect(find.text('꺼짐'), findsOneWidget);
    expect(find.text('켜짐'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          hasRequiredInfo: false,
          userId: 'user-1',
          deviceId: 'ios-device',
          userDataRepository: repository,
          notificationPermissionService: _FakeNotificationPermissionService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('복약관리'));
    await tester.pumpAndSettle();

    expect(find.text('공통약'), findsOneWidget);
    expect(find.text('켜짐'), findsOneWidget);
  });

  testWidgets('sign out waits for pending user data save',
      (WidgetTester tester) async {
    final repository = _DelayedUserDataRepository();
    var signedOut = false;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          hasRequiredInfo: true,
          userId: 'user-1',
          userDataRepository: repository,
          notificationPermissionService: _FakeNotificationPermissionService(),
          onSignOut: () async {
            signedOut = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('마이페이지'));
    await tester.pumpAndSettle();

    await tester
        .tap(find.byKey(const ValueKey('notification-permission-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('허용'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, -800));
    await tester.pumpAndSettle();
    final signOutButton = find.widgetWithText(OutlinedButton, '로그아웃').last;
    await tester.tap(signOutButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(signedOut, isFalse);
    expect(
      find.text('데이터를 저장 중입니다. 저장 완료 시 로그아웃됩니다.'),
      findsNothing,
    );
    repository.completeSave();
    await tester.pumpAndSettle();

    expect(repository.savedSettings, isTrue);
    expect(signedOut, isTrue);
  });

  testWidgets('sign out proceeds when pending medication reminder save stalls',
      (WidgetTester tester) async {
    final repository = _DelayedMedicationSaveRepository();
    var signedOut = false;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          hasRequiredInfo: true,
          userId: 'user-1',
          userDataRepository: repository,
          notificationPermissionService: _FakeNotificationPermissionService(),
          onSignOut: () async {
            signedOut = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('복약관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '약물 등록'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '항구토제');
    await tester.enterText(find.byType(TextFormField).at(1), '1정');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('꺼짐'), findsOneWidget);
    expect(repository.savedMedications.single.reminderEnabled, isFalse);

    await tester.tap(find.text('마이페이지'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -800));
    await tester.pumpAndSettle();

    final signOutButton = find.widgetWithText(OutlinedButton, '로그아웃').last;
    await tester.tap(signOutButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2300));

    expect(signedOut, isTrue);
  });

  testWidgets('sign out proceeds when pending user data save stalls',
      (WidgetTester tester) async {
    final repository = _DelayedUserDataRepository();
    var signedOut = false;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          hasRequiredInfo: true,
          userId: 'user-1',
          userDataRepository: repository,
          notificationPermissionService: _FakeNotificationPermissionService(),
          onSignOut: () async {
            signedOut = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('마이페이지'));
    await tester.pumpAndSettle();

    await tester
        .tap(find.byKey(const ValueKey('notification-permission-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('허용'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, -800));
    await tester.pumpAndSettle();
    final signOutButton = find.widgetWithText(OutlinedButton, '로그아웃').last;
    await tester.tap(signOutButton);
    await tester.pump();

    expect(signedOut, isFalse);
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pumpAndSettle();

    expect(repository.savedSettings, isTrue);
    expect(signedOut, isTrue);
  });
}

class _FakeNotificationPermissionService
    implements NotificationPermissionService {
  final _payloadController = StreamController<String>.broadcast();
  final syncedMedicationBatches = <List<Medication>>[];

  void emitPayload(String payload) {
    _payloadController.add(payload);
  }

  @override
  Stream<String> get notificationPayloads => _payloadController.stream;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> syncMedicationReminders(Iterable<Medication> medications) async {
    syncedMedicationBatches.add(medications.toList(growable: false));
  }

  @override
  Future<void> cancelMedicationReminders(int medicationId) async {}

  @override
  Future<int> pendingMedicationReminderCount() async => 1;

  @override
  Future<String?> takeLaunchPayload() async => null;
}

class _FakeStepSyncService implements StepSyncService {
  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<int?> readTodaySteps() async => 2400;
}

class _NullStepSyncService implements StepSyncService {
  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<int?> readTodaySteps() async => null;
}

class _DeviceScopedSettingsRepository extends UserDataRepository {
  _DeviceScopedSettingsRepository({
    this.settingsByDevice = const {},
    this.medications = const [],
  });

  final Map<String, UserSettings> settingsByDevice;
  final List<Medication> medications;
  String? savedDeviceId;
  UserSettings? savedSettings;
  var savedMedications = <Medication>[];

  @override
  Future<UserDataSnapshot> load(String userId, {String? deviceId}) async {
    return UserDataSnapshot(
      settings: settingsByDevice[deviceId] ?? const UserSettings(),
      profile: UserProfile(
        sex: '여성',
        birthDate: DateTime(1974, 3, 12),
        cancerType: '유방암',
        stage: '2기',
        diagnosisDate: DateTime(2026, 1, 15),
        metastasis: '없음',
        treatmentType: '항암치료',
        treatmentStartDate: DateTime(2026, 4, 1),
        heightCm: 162,
      ),
      medications: medications,
    );
  }

  @override
  Future<void> saveSettings(
    String userId,
    UserSettings settings, {
    String? deviceId,
  }) async {
    savedDeviceId = deviceId;
    savedSettings = settings;
  }

  @override
  Future<void> saveMedications(
      String userId, List<Medication> medications) async {
    savedMedications = medications;
  }
}

class _DelayedUserDataRepository extends UserDataRepository {
  Completer<void>? _saveCompleter;
  var savedSettings = false;

  @override
  Future<UserDataSnapshot> load(String userId, {String? deviceId}) async {
    return UserDataSnapshot(
      settings: const UserSettings(),
      profile: UserProfile(
        sex: '여성',
        birthDate: DateTime(1974, 3, 12),
        cancerType: '유방암',
        stage: '2기',
        diagnosisDate: DateTime(2026, 1, 15),
        metastasis: '없음',
        treatmentType: '항암치료',
        treatmentStartDate: DateTime(2026, 4, 1),
        heightCm: 162,
      ),
    );
  }

  @override
  Future<void> saveSettings(
    String userId,
    UserSettings settings, {
    String? deviceId,
  }) {
    savedSettings = true;
    _saveCompleter = Completer<void>();
    return _saveCompleter!.future;
  }

  void completeSave() {
    _saveCompleter?.complete();
  }
}

class _FailingLoadUserDataRepository extends UserDataRepository {
  @override
  Future<UserDataSnapshot> load(String userId, {String? deviceId}) async {
    throw Exception('network unavailable');
  }

  @override
  Future<UserDataSnapshot?> loadCachedSnapshot(
    String userId, {
    String? deviceId,
  }) async =>
      null;
}

class _DelayedMedicationSaveRepository extends UserDataRepository {
  final _saveCompleter = Completer<void>();
  var savedMedications = <Medication>[];

  @override
  Future<UserDataSnapshot> load(String userId, {String? deviceId}) async {
    return UserDataSnapshot(
      settings: const UserSettings(),
      profile: UserProfile(
        sex: '여성',
        birthDate: DateTime(1974, 3, 12),
        cancerType: '유방암',
        stage: '2기',
        diagnosisDate: DateTime(2026, 1, 15),
        metastasis: '없음',
        treatmentType: '항암치료',
        treatmentStartDate: DateTime(2026, 4, 1),
        heightCm: 162,
      ),
    );
  }

  @override
  Future<void> saveMedications(String userId, List<Medication> medications) {
    savedMedications = medications;
    return _saveCompleter.future;
  }

  void completeMedicationSave() {
    _saveCompleter.complete();
  }
}

class _CachedMedicationUserDataRepository extends UserDataRepository {
  @override
  Future<UserDataSnapshot> load(String userId, {String? deviceId}) async {
    throw Exception('network unavailable');
  }

  @override
  Future<UserDataSnapshot?> loadCachedSnapshot(
    String userId, {
    String? deviceId,
  }) async {
    return UserDataSnapshot(
      settings: const UserSettings(),
      profile: UserProfile(
        sex: '여성',
        birthDate: DateTime(1974, 3, 12),
        cancerType: '유방암',
        stage: '2기',
        diagnosisDate: DateTime(2026, 1, 15),
        metastasis: '없음',
        treatmentType: '항암치료',
        treatmentStartDate: DateTime(2026, 4, 1),
        heightCm: 162,
      ),
      medications: const [
        Medication(
          id: 1,
          name: '항구토제',
          dose: '1정',
          frequency: '',
          weekdays: [],
          reminderEnabled: false,
          reminders: [],
        ),
      ],
    );
  }
}

class _RemoteMedicationWithStaleCacheRepository extends UserDataRepository {
  var cachedSnapshotSaved = false;

  @override
  Future<UserDataSnapshot> load(String userId, {String? deviceId}) async {
    return UserDataSnapshot(
      settings: const UserSettings(),
      profile: UserProfile(
        sex: '여성',
        birthDate: DateTime(1974, 3, 12),
        cancerType: '유방암',
        stage: '2기',
        diagnosisDate: DateTime(2026, 1, 15),
        metastasis: '없음',
        treatmentType: '항암치료',
        treatmentStartDate: DateTime(2026, 4, 1),
        heightCm: 162,
      ),
      medications: const [
        Medication(
          id: 1,
          name: '서버약',
          dose: '1정',
          frequency: '',
          weekdays: [],
          reminderEnabled: false,
          reminders: [],
        ),
      ],
    );
  }

  @override
  Future<UserDataSnapshot?> loadCachedSnapshot(
    String userId, {
    String? deviceId,
  }) async {
    return UserDataSnapshot(
      settings: const UserSettings(),
      profile: UserProfile(
        sex: '여성',
        birthDate: DateTime(1974, 3, 12),
        cancerType: '유방암',
        stage: '2기',
        diagnosisDate: DateTime(2026, 1, 15),
        metastasis: '없음',
        treatmentType: '항암치료',
        treatmentStartDate: DateTime(2026, 4, 1),
        heightCm: 162,
      ),
      medications: const [
        Medication(
          id: 1,
          name: '캐시약',
          dose: '1정',
          frequency: '',
          weekdays: [],
          reminderEnabled: false,
          reminders: [],
        ),
      ],
    );
  }

  @override
  Future<void> saveCachedSnapshot(
    String userId,
    UserDataSnapshot snapshot, {
    String? deviceId,
  }) async {
    cachedSnapshotSaved = true;
  }
}

class _DelayedLoadUserDataRepository extends UserDataRepository {
  final _loadCompleter = Completer<UserDataSnapshot>();

  @override
  Future<UserDataSnapshot> load(String userId, {String? deviceId}) =>
      _loadCompleter.future;

  void completeLoad() {
    _loadCompleter.complete(
      UserDataSnapshot(
        settings: const UserSettings(),
        profile: UserProfile(
          sex: '여성',
          birthDate: DateTime(1974, 3, 12),
          cancerType: '유방암',
          stage: '2기',
          diagnosisDate: DateTime(2026, 1, 15),
          metastasis: '없음',
          treatmentType: '항암치료',
          treatmentStartDate: DateTime(2026, 4, 1),
          heightCm: 162,
        ),
      ),
    );
  }
}

String _testFormatDate([DateTime? value]) {
  final date = value ?? DateTime.now();
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

Finder get _symptomEditorScrollable => find
    .descendant(
      of: find.byKey(const ValueKey('symptom-editor-scroll')),
      matching: find.byType(Scrollable),
    )
    .first;
