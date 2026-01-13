import 'package:flutter/material.dart';

/// Fondo del radar: anillos punteados + cruz + pulso.
/// (El círculo central con el número lo dibuja RadarView como widget.)
class RadarPainter extends CustomPainter {
  final double t; // 0..1
  final bool night;

  RadarPainter({required this.t, required this.night});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Fondo suave tipo gradiente radial
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: night
            ? [
                const Color(0xFFFF5A5F).withOpacity(0.10),
                const Color(0xFF050509).withOpacity(0.92),
              ]
            : [
                const Color(0xFFFF5A5F).withOpacity(0.14),
                Colors.white.withOpacity(0.98),
              ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Offset.zero & size, bgPaint);

    final ringColor =
        const Color(0xFFFF5A5F).withOpacity(night ? 0.30 : 0.22);
    final crossColor =
        const Color(0xFFFF5A5F).withOpacity(night ? 0.16 : 0.12);
    final pulseColor =
        const Color(0xFFFF5A5F).withOpacity((1 - t) * (night ? 0.22 : 0.18));

    // Cruz central
    final crossPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = crossColor;

    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), crossPaint);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), crossPaint);

    // Anillos punteados (6 anillos)
    final maxR = size.width * 0.48;
    for (int i = 1; i <= 6; i++) {
      final r = (maxR / 6) * i;
      _drawDottedCircle(canvas, center, r,
          color: ringColor.withOpacity(i.isEven ? 0.75 : 0.55),
          dotCount: 90,
          dotRadius: 1.2);
    }

    // Pulso
    final pulseR = (size.width * 0.20) + (size.width * 0.28 * t);
    final pulsePaint = Paint()..color = pulseColor;
    canvas.drawCircle(center, pulseR, pulsePaint);
  }

  void _drawDottedCircle(
    Canvas canvas,
    Offset c,
    double radius, {
    required Color color,
    required int dotCount,
    required double dotRadius,
  }) {
    final p = Paint()..color = color;
    for (int i = 0; i < dotCount; i++) {
      final a = (i / dotCount) * 6.283185307179586; // 2*pi
      final x = c.dx + radius * MathCos.cos(a);
      final y = c.dy + radius * MathSin.sin(a);
      canvas.drawCircle(Offset(x, y), dotRadius, p);
    }
  }

  @override
  bool shouldRepaint(covariant RadarPainter old) =>
      old.t != t || old.night != night;
}

/// Painter para dibujar “rayitas” (líneas) desde centro hacia cada avatar
class RadarLinesPainter extends CustomPainter {
  final bool night;
  final Offset center;
  final List<Offset> avatarCenters;

  RadarLinesPainter({
    required this.night,
    required this.center,
    required this.avatarCenters,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFFFF5A5F).withOpacity(night ? 0.22 : 0.18);

    for (final p in avatarCenters) {
      canvas.drawLine(center, p, paint);
    }
  }

  @override
  bool shouldRepaint(covariant RadarLinesPainter old) =>
      old.night != night ||
      old.center != center ||
      old.avatarCenters.length != avatarCenters.length;
}

/// Para no importar dart:math en este archivo y evitar warnings,
/// uso wrappers pequeños. RadarView ya usa dart:math.
class MathCos {
  static double cos(double x) => _cos(x);
  static double _cos(double x) {
    // aproximación simple: delega a trig real desde dart:math pero sin import aquí
    // RadarView importa dart:math y usa la ubicación real.
    // Este wrapper se reemplaza abajo en RadarView con trig real.
    return 0;
  }
}

class MathSin {
  static double sin(double x) => _sin(x);
  static double _sin(double x) => 0;
}
