import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cancer_monitor/src/app/cancer_monitor_app.dart';
import 'package:cancer_monitor/src/features/home_shell.dart';
import 'package:cancer_monitor/src/features/medication/medication_screen.dart';
import 'package:cancer_monitor/src/services/notifications/notification_permission_service.dart';

void main() {
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
    await tester.scrollUntilVisible(signOutButton, 350);
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

  testWidgets('preview profile shows required info flow and exit action',
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

    expect(find.text('사용자 정보'), findsWidgets);
    expect(find.byType(TextFormField), findsWidgets);
    expect(find.text('저장'), findsOneWidget);

    await tester.tap(find.byTooltip('이전'));
    await tester.pumpAndSettle();

    final exitPreviewButton = find.widgetWithText(OutlinedButton, '둘러보기 나가기');
    await tester.scrollUntilVisible(exitPreviewButton, 350);
    await tester.pumpAndSettle();

    expect(exitPreviewButton, findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '로그아웃'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, '회원탈퇴'), findsNothing);
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
    await tester.tap(find.text('허용'));
    await tester.pumpAndSettle();

    expect(find.text('항구토제'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.tap(find.text('마이페이지'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('복약관리'));
    await tester.pumpAndSettle();

    expect(find.text('항구토제'), findsOneWidget);
  });
}

class _FakeNotificationPermissionService
    implements NotificationPermissionService {
  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> scheduleMedicationReminder({
    required String medicationId,
    required String title,
    required DateTime scheduledAt,
  }) async {}
}
