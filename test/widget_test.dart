import 'package:flutter_test/flutter_test.dart';

import 'package:cancer_monitor/src/app/cancer_monitor_app.dart';

void main() {
  testWidgets('shows the bottom navigation shell', (WidgetTester tester) async {
    await tester.pumpWidget(const CancerMonitorApp());

    expect(find.text('마이페이지'), findsOneWidget);
    expect(find.text('복약관리'), findsOneWidget);
    expect(find.text('체중관리'), findsOneWidget);
    expect(find.text('증상관리'), findsOneWidget);
    expect(find.text('AI분석'), findsOneWidget);
  });
}
