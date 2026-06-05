import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'analysis/analysis_screen.dart';
import 'medication/medication_screen.dart';
import 'profile/profile_screen.dart';
import 'symptom/symptom_screen.dart';
import 'weight/weight_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // Firebase/profile state가 붙기 전까지는 사용자정보가 있다고 가정하고 증상관리에서 시작한다.
  // 실제 연동 후에는 사용자정보/주의정보가 없으면 마이페이지(index 0), 있으면 증상관리(index 3)로 분기한다.
  var _index = 3;

  static const _screens = [
    ProfileScreen(),
    MedicationScreen(),
    WeightScreen(),
    SymptomScreen(),
    AnalysisScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: _screens[_index],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        height: 74,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.accentSoft,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '마이페이지',
          ),
          NavigationDestination(
            icon: _CapsuleIcon(),
            selectedIcon: _CapsuleIcon(selected: true),
            label: '복약관리',
          ),
          NavigationDestination(
            icon: _ScaleIcon(),
            selectedIcon: _ScaleIcon(selected: true),
            label: '체중관리',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: '증상관리',
          ),
          NavigationDestination(
            icon: _AiIcon(),
            selectedIcon: _AiIcon(selected: true),
            label: 'AI분석',
          ),
        ],
      ),
    );
  }
}

class _CapsuleIcon extends StatelessWidget {
  const _CapsuleIcon({this.selected = false});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.muted;
    return SizedBox(
      width: 25,
      height: 25,
      child: Transform.rotate(
        angle: -0.78,
        child: CustomPaint(
          painter: _CapsulePainter(color: color, filled: selected),
        ),
      ),
    );
  }
}

class _CapsulePainter extends CustomPainter {
  const _CapsulePainter({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(3, 7, size.width - 6, 11);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7;
    final fill = Paint()
      ..color = color.withValues(alpha: filled ? .95 : .22)
      ..style = PaintingStyle.fill;

    final leftHalf =
        Rect.fromLTRB(rect.left, rect.top, rect.center.dx, rect.bottom);
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(leftHalf, fill);
    canvas.restore();
    canvas.drawRRect(rrect, stroke);
    canvas.drawLine(Offset(rect.center.dx, rect.top),
        Offset(rect.center.dx, rect.bottom), stroke);
  }

  @override
  bool shouldRepaint(covariant _CapsulePainter oldDelegate) {
    return color != oldDelegate.color || filled != oldDelegate.filled;
  }
}

class _ScaleIcon extends StatelessWidget {
  const _ScaleIcon({this.selected = false});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.muted;
    return SizedBox(
      width: 25,
      height: 25,
      child: CustomPaint(painter: _ScalePainter(color: color)),
    );
  }
}

class _ScalePainter extends CustomPainter {
  const _ScalePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(5, 4, size.width - 10, size.height - 6),
      const Radius.circular(5),
    );
    final display = RRect.fromRectAndRadius(
      Rect.fromLTWH(8.5, 7.5, size.width - 17, 5.5),
      const Radius.circular(2),
    );
    canvas.drawRRect(body, stroke);
    canvas.drawRRect(display, stroke);
    canvas.drawLine(
        Offset(size.width / 2, 15), Offset(size.width / 2, 18), stroke);
  }

  @override
  bool shouldRepaint(covariant _ScalePainter oldDelegate) =>
      color != oldDelegate.color;
}

class _AiIcon extends StatelessWidget {
  const _AiIcon({this.selected = false});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.muted;
    return Container(
      width: 25,
      height: 25,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.6),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        'AI',
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}
