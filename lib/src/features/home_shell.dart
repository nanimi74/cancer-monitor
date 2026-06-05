import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'analysis/analysis_screen.dart';
import 'medication/medication_screen.dart';
import 'profile/profile_screen.dart';
import 'symptom/symptom_screen.dart';
import 'weight/weight_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    this.isPreview = false,
    this.hasRequiredInfo = true,
  });

  final bool isPreview;
  final bool hasRequiredInfo;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late var _index = widget.hasRequiredInfo ? 3 : 0;

  late final _screens = [
    ProfileScreen(
      hasRequiredInfo: widget.hasRequiredInfo,
      isPreview: widget.isPreview,
    ),
    const MedicationScreen(),
    const WeightScreen(),
    const SymptomScreen(),
    const AnalysisScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width =
                constraints.maxWidth > 680 ? 680.0 : constraints.maxWidth;
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: width,
                height: constraints.maxHeight,
                child: _screens[_index],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .97),
          border: const Border(top: BorderSide(color: AppColors.line)),
          boxShadow: [
            BoxShadow(
              color: AppColors.text.withValues(alpha: .08),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 74,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 7, 14, 9),
                  child: NavigationBarTheme(
                    data: NavigationBarThemeData(
                      indicatorColor: Colors.transparent,
                      labelTextStyle: WidgetStateProperty.resolveWith(
                        (states) => TextStyle(
                          color: states.contains(WidgetState.selected)
                              ? AppColors.accent
                              : AppColors.muted,
                          fontSize: 12,
                          fontWeight: states.contains(WidgetState.selected)
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                      iconTheme: WidgetStateProperty.resolveWith(
                        (states) => IconThemeData(
                          color: states.contains(WidgetState.selected)
                              ? AppColors.accent
                              : AppColors.muted,
                          size: 27,
                        ),
                      ),
                    ),
                    child: NavigationBar(
                      selectedIndex: _index,
                      height: 58,
                      elevation: 0,
                      backgroundColor: Colors.transparent,
                      indicatorColor: Colors.transparent,
                      labelBehavior:
                          NavigationDestinationLabelBehavior.alwaysShow,
                      onDestinationSelected: (index) =>
                          setState(() => _index = index),
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.person_outline),
                          selectedIcon: Icon(Icons.person_outline),
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
                          selectedIcon: Icon(Icons.calendar_month_outlined),
                          label: '증상관리',
                        ),
                        NavigationDestination(
                          icon: _AiIcon(),
                          selectedIcon: _AiIcon(selected: true),
                          label: 'AI분석',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
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
