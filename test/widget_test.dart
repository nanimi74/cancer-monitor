import 'package:flutter_test/flutter_test.dart';

import 'package:cancer_monitor/src/app/cancer_monitor_app.dart';

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
  });

  testWidgets('opens login screen and signs in with email',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CancerMonitorApp());

    await tester.tap(find.text('로그인하고 시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('로그인'), findsOneWidget);
    expect(find.text('회원 전용 서비스입니다.\n비회원의 경우 가입 후 이용해주세요.'), findsOneWidget);

    await tester.tap(find.text('이메일로 계속하기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('마이페이지'), findsWidgets);
    expect(find.text('복약관리'), findsOneWidget);
    expect(find.text('체중관리'), findsOneWidget);
    expect(find.text('증상관리'), findsOneWidget);
    expect(find.text('AI분석'), findsOneWidget);
  });
}
