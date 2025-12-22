import 'package:flutter/material.dart';

/// =============================================================
/// PINTOR DEL RADAR — círculos, cruz central, pulso animado
/// =============================================================
class RadarPainter extends CustomPainter {
  final double t; // 0..1
  final bool night;

  RadarPainter({required this.t, required this.night});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final ringColor =
        const Color(0xFFFF5A5F).withOpacity(night ? 0.28 : 0.22);
    final crossColor =
        const Color(0xFFFF5A5F).withOpacity(night ? 0.18 : 0.14);
    final pulseColor =
        const Color(0xFFFF5A5F).withOpacity((1 - t) * 0.18);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = ringColor;

    final crossPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = crossColor;

    final pulsePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = pulseColor;

    final r1 = size.width * 0.32;
    final r2 = size.width * 0.44;

    canvas.drawCircle(center, r1, ringPaint);
    canvas.drawCircle(center, r2, ringPaint);

    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      crossPaint,
    );
    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      crossPaint,
    );

    final pulseR = (size.width * 0.26) + (size.width * 0.24 * t);
    canvas.drawCircle(center, pulseR, pulsePaint);
  }

  @override
  bool shouldRepaint(covariant RadarPainter old) =>
      old.t != t || old.night != night;
}
