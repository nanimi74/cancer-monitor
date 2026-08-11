import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class EntryScreen extends StatelessWidget {
  const EntryScreen({
    super.key,
    required this.onLogin,
    required this.onPreview,
  });

  final VoidCallback onLogin;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 42, 24, 32),
              children: [
                const _EntryBrand(),
                const SizedBox(height: 34),
                Text(
                  '매일의 기록을\n부담 없이 정리해요.',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontSize: 28,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 24),
                const _FeatureList(),
                const SizedBox(height: 34),
                ElevatedButton(
                  onPressed: onLogin,
                  child: const Text('로그인하고 시작하기'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: onPreview,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    foregroundColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.accentLine),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '둘러보기',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '둘러보기에서는 앱 화면만 확인할 수 있고, 기록은 저장되지 않아요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryBrand extends StatelessWidget {
  const _EntryBrand();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _EntryLogo(size: 46),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '한결',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            SizedBox(height: 2),
            Text(
              '치료 중 일상 기록을 한 곳에',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

class _EntryLogo extends StatelessWidget {
  const _EntryLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .22),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: .22),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * .22),
        child: Image.asset(
          'assets/app_icon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _FeatureList extends StatelessWidget {
  const _FeatureList();

  @override
  Widget build(BuildContext context) {
    const items = [
      _FeatureItemData(
        title: '복약관리',
        description: '복용 약과 알림을 관리해요.',
        icon: _FeatureIconType.medication,
      ),
      _FeatureItemData(
        title: '체중관리',
        description: 'BMI와 체중 변화를 확인해요.',
        icon: _FeatureIconType.weight,
      ),
      _FeatureItemData(
        title: '증상관리',
        description: '식사, 배변, 운동량, 컨디션을 기록해요.',
        icon: _FeatureIconType.symptom,
      ),
      _FeatureItemData(
        title: 'AI요약',
        description: '회차별 기록을 요약하고 흐름을 정리해요.',
        icon: _FeatureIconType.analysis,
      ),
    ];

    return Column(
      children: [
        for (final item in items) ...[
          _FeatureItem(item: item),
          if (item != items.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({required this.item});

  final _FeatureItemData item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _FeatureIcon(type: item.icon),
          const SizedBox(width: 12),
          Text(
            item.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.description,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureIcon extends StatelessWidget {
  const _FeatureIcon({required this.type});

  final _FeatureIconType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: CustomPaint(painter: _FeatureIconPainter(type)),
    );
  }
}

class _FeatureIconPainter extends CustomPainter {
  const _FeatureIconPainter(this.type);

  final _FeatureIconType type;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.45
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.fill;

    switch (type) {
      case _FeatureIconType.medication:
        canvas.save();
        canvas.translate(size.width / 2, size.height / 2);
        canvas.rotate(-.78);
        final pill = RRect.fromRectAndRadius(
          const Rect.fromLTWH(-9, -4, 18, 8),
          const Radius.circular(5),
        );
        canvas.drawRRect(pill, stroke);
        canvas.save();
        canvas.clipRRect(pill);
        canvas.drawRect(const Rect.fromLTWH(-9, -4, 9, 8), fill);
        canvas.restore();
        canvas.drawLine(const Offset(0, -4), const Offset(0, 4), stroke);
        canvas.restore();
      case _FeatureIconType.weight:
        final body = RRect.fromRectAndRadius(
          const Rect.fromLTWH(8, 6, 14, 18),
          const Radius.circular(4),
        );
        canvas.drawRRect(body, stroke);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(11, 9, 8, 5),
            const Radius.circular(2),
          ),
          stroke,
        );
      case _FeatureIconType.symptom:
        final calendar = RRect.fromRectAndRadius(
          const Rect.fromLTWH(7, 6, 16, 18),
          const Radius.circular(4),
        );
        canvas.drawRRect(calendar, stroke);
        canvas.drawLine(const Offset(7, 11), const Offset(23, 11), stroke);
        canvas.drawLine(const Offset(11, 4), const Offset(11, 8), stroke);
        canvas.drawLine(const Offset(19, 4), const Offset(19, 8), stroke);
        canvas.drawCircle(const Offset(13, 17), 1.1, fill);
        canvas.drawCircle(const Offset(18, 17), 1.1, fill);
      case _FeatureIconType.analysis:
        canvas.drawCircle(Offset(size.width / 2, size.height / 2), 9, stroke);
        final textPainter = TextPainter(
          text: const TextSpan(
            text: 'AI',
            style: TextStyle(
              color: AppColors.accent,
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          Offset(
            (size.width - textPainter.width) / 2,
            (size.height - textPainter.height) / 2,
          ),
        );
    }
  }

  @override
  bool shouldRepaint(covariant _FeatureIconPainter oldDelegate) =>
      type != oldDelegate.type;
}

class _FeatureItemData {
  const _FeatureItemData({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final _FeatureIconType icon;
}

enum _FeatureIconType {
  medication,
  weight,
  symptom,
  analysis,
}
