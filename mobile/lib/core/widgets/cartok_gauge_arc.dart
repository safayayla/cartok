import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/cartok_colors.dart';

/// The app's signature element: a partial gauge arc, like the sweep on a
/// tachometer face. Used wherever we show "progress toward a value" —
/// profile/vehicle verification, a stat ring on the garage header, or (as
/// an indeterminate sweep) a loading state. Reused deliberately so it reads
/// as one consistent idea rather than a one-off decoration.
class CartokGaugeArc extends StatelessWidget {
  const CartokGaugeArc({
    super.key,
    required this.progress, // 0.0 - 1.0, null = indeterminate sweep
    required this.size,
    this.strokeWidth = 8,
    this.colors = CartokColors.redlineArc,
    this.trackColor = CartokColors.surfaceElevated,
    this.center,
  });

  final double? progress;
  final double size;
  final double strokeWidth;
  final List<Color> colors;
  final Color trackColor;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _GaugeArcPainter(
              progress: progress,
              strokeWidth: strokeWidth,
              colors: colors,
              trackColor: trackColor,
            ),
          ),
          if (center != null) center!,
        ],
      ),
    );
  }
}

class _GaugeArcPainter extends CustomPainter {
  _GaugeArcPainter({
    required this.progress,
    required this.strokeWidth,
    required this.colors,
    required this.trackColor,
  });

  final double? progress;
  final double strokeWidth;
  final List<Color> colors;
  final Color trackColor;

  // A tachometer reads roughly 270° — we mirror that instead of a full circle,
  // so the shape itself is recognizably "gauge," not "generic progress ring."
  static const double _startAngle = math.pi * 0.75;
  static const double _sweepAngle = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, _startAngle, _sweepAngle, false, trackPaint);

    final sweep = progress != null ? _sweepAngle * progress!.clamp(0.0, 1.0) : _sweepAngle * 0.28;

    final gradient = SweepGradient(
      startAngle: _startAngle,
      endAngle: _startAngle + _sweepAngle,
      colors: colors,
      transform: GradientRotation(_startAngle),
    );

    final progressPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, _startAngle, sweep, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugeArcPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.colors != colors;
}
