import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:latlong2/latlong.dart' show Distance, LengthUnit;

import '../explore_models.dart';

class RadarView extends StatelessWidget {
  final bool night;
  final bool isLoading;
  final AnimationController controller;

  /// Lista real de usuarios (para avatares)
  final List<NearbyUser> users;

  /// Centro (tu ubicación) y radio del radar (m)
  final LatLng center;
  final double radarMeters;

  const RadarView({
    super.key,
    required this.night,
    required this.isLoading,
    required this.controller,
    required this.users,
    required this.center,
    required this.radarMeters,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final size = math.min(c.maxWidth, c.maxHeight) * 0.98;

        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: AnimatedBuilder(
              animation: controller,
              builder: (_, __) {
                final t = controller.value;

                return _RadarScene(
                  night: night,
                  t: t,
                  isLoading: isLoading,
                  users: users,
                  center: center,
                  radarMeters: radarMeters,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _RadarScene extends StatelessWidget {
  final bool night;
  final double t;
  final bool isLoading;
  final List<NearbyUser> users;
  final LatLng center;
  final double radarMeters;

  const _RadarScene({
    required this.night,
    required this.t,
    required this.isLoading,
    required this.users,
    required this.center,
    required this.radarMeters,
  });

  @override
  Widget build(BuildContext context) {
    // Radar geometry
    final count = users.length;
    final dist = const Distance();

    return LayoutBuilder(
      builder: (_, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        final centerOffset = Offset(w / 2, h / 2);

        // Zona útil para avatares (evita tapar el círculo central)
        final outerR = w * 0.46;
        final innerR = w * 0.30;

        // Calculamos posiciones de cada usuario:
        // - ángulo estable por usuario (hash)
        // - radio proporcional a la distancia (0..radarMeters)
        final avatarDots = <_AvatarDot>[];

        for (final u in users) {
          final dMeters = dist.as(
            LengthUnit.Meter,
            center,
            LatLng(u.lat, u.lng),
          );

          final frac = (radarMeters <= 0)
              ? 1.0
              : (dMeters / radarMeters).clamp(0.12, 1.0);

          final r = innerR + (outerR - innerR) * frac;

          final a = _stableAngle(u); // 0..2pi
          final dx = r * math.cos(a);
          final dy = r * math.sin(a);

          avatarDots.add(
            _AvatarDot(
              user: u,
              center: Offset(centerOffset.dx + dx, centerOffset.dy + dy),
              meters: dMeters,
            ),
          );
        }

        return Stack(
          children: [
            // Fondo + anillos + pulso
            CustomPaint(
              size: Size(w, h),
              painter: _RadarBackgroundPainter(t: t, night: night),
            ),

            // Rayitas hacia cada avatar
            CustomPaint(
              size: Size(w, h),
              painter: _RadarLinesPainter(
                night: night,
                center: centerOffset,
                avatarCenters: avatarDots.map((e) => e.center).toList(),
              ),
            ),

            // Avatares
            ...avatarDots.map((dot) {
              final avatarSize = 44.0;
              return Positioned(
                left: dot.center.dx - avatarSize / 2,
                top: dot.center.dy - avatarSize / 2,
                child: _AvatarBubble(
                  night: night,
                  user: dot.user,
                  meters: dot.meters,
                  size: avatarSize,
                ),
              );
            }),

            // Círculo central + número
            Center(
              child: _CenterBubble(
                night: night,
                isLoading: isLoading,
                count: count,
                size: w * 0.42,
              ),
            ),
          ],
        );
      },
    );
  }

  double _stableAngle(NearbyUser u) {
    // Ángulo estable por usuario: usa id si existe, si no, usa nombre+coords
    final base = (u.id ?? 0).toString() +
        '|' +
        u.name +
        '|' +
        u.lat.toStringAsFixed(5) +
        '|' +
        u.lng.toStringAsFixed(5);

    int h = 0;
    for (int i = 0; i < base.length; i++) {
      h = 31 * h + base.codeUnitAt(i);
    }
    final normalized = (h.abs() % 1000000) / 1000000.0; // 0..1
    return normalized * 2 * math.pi;
  }
}

/// ---------------------------
/// Painter del fondo del radar
/// ---------------------------
class _RadarBackgroundPainter extends CustomPainter {
  final double t;
  final bool night;

  _RadarBackgroundPainter({required this.t, required this.night});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);

    // Fondo radial suave
    final bg = Paint()
      ..shader = RadialGradient(
        colors: night
            ? [
                const Color(0xFFFF5A5F).withOpacity(0.10),
                const Color(0xFF050509).withOpacity(0.94),
              ]
            : [
                const Color(0xFFFF5A5F).withOpacity(0.14),
                Colors.white.withOpacity(0.98),
              ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Offset.zero & size, bg);

    // Cruz
    final cross = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFFF5A5F).withOpacity(night ? 0.16 : 0.12);

    canvas.drawLine(Offset(c.dx, 0), Offset(c.dx, size.height), cross);
    canvas.drawLine(Offset(0, c.dy), Offset(size.width, c.dy), cross);

    // Anillos punteados
    final ringColor =
        const Color(0xFFFF5A5F).withOpacity(night ? 0.28 : 0.22);
    final maxR = size.width * 0.48;

    for (int i = 1; i <= 7; i++) {
      final r = (maxR / 7) * i;
      _dottedCircle(
        canvas,
        c,
        r,
        color: ringColor.withOpacity(i.isEven ? 0.72 : 0.54),
        dotCount: 96,
        dotRadius: 1.2,
      );
    }

    // Pulso
    final pulseColor =
        const Color(0xFFFF5A5F).withOpacity((1 - t) * (night ? 0.22 : 0.18));
    final pulseR = (size.width * 0.18) + (size.width * 0.30 * t);

    canvas.drawCircle(c, pulseR, Paint()..color = pulseColor);
  }

  void _dottedCircle(
    Canvas canvas,
    Offset c,
    double r, {
    required Color color,
    required int dotCount,
    required double dotRadius,
  }) {
    final p = Paint()..color = color;
    for (int i = 0; i < dotCount; i++) {
      final a = (i / dotCount) * 2 * math.pi;
      final x = c.dx + r * math.cos(a);
      final y = c.dy + r * math.sin(a);
      canvas.drawCircle(Offset(x, y), dotRadius, p);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarBackgroundPainter old) =>
      old.t != t || old.night != night;
}

/// ---------------------------
/// Painter de las líneas
/// ---------------------------
class _RadarLinesPainter extends CustomPainter {
  final bool night;
  final Offset center;
  final List<Offset> avatarCenters;

  _RadarLinesPainter({
    required this.night,
    required this.center,
    required this.avatarCenters,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFF5A5F).withOpacity(night ? 0.22 : 0.18);

    for (final a in avatarCenters) {
      canvas.drawLine(center, a, p);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarLinesPainter old) =>
      old.night != night ||
      old.center != center ||
      old.avatarCenters.length != avatarCenters.length;
}

/// ---------------------------
/// Avatar bubble (círculo)
/// ---------------------------
class _AvatarBubble extends StatelessWidget {
  final bool night;
  final NearbyUser user;
  final double meters;
  final double size;

  const _AvatarBubble({
    required this.night,
    required this.user,
    required this.meters,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final km = meters / 1000.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: night ? Colors.black.withOpacity(0.65) : Colors.white,
            border: Border.all(color: const Color(0xFFFF5A5F), width: 2),
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                spreadRadius: 1,
                color: Colors.black.withOpacity(0.18),
              ),
            ],
          ),
          child: ClipOval(
            child: (user.avatarUrl != null && user.avatarUrl!.trim().isNotEmpty)
                ? Image.network(
                    user.avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallback(),
                  )
                : _fallback(),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 76,
          child: Text(
            user.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: night ? Colors.white70 : Colors.black54,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ),
        SizedBox(
          width: 76,
          child: Text(
            km < 1 ? "${meters.toStringAsFixed(0)} m" : "${km.toStringAsFixed(2)} km",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: night ? Colors.white54 : Colors.black45,
              fontWeight: FontWeight.w600,
              fontSize: 10.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _fallback() {
    final initial = user.name.trim().isNotEmpty ? user.name.trim()[0].toUpperCase() : "U";
    return Container(
      color: const Color(0xFF111827),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

/// ---------------------------
/// Centro (contador)
/// ---------------------------
class _CenterBubble extends StatelessWidget {
  final bool night;
  final bool isLoading;
  final int count;
  final double size;

  const _CenterBubble({
    required this.night,
    required this.isLoading,
    required this.count,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final outer = size;
    final inner = size * 0.72;

    return Container(
      width: outer,
      height: outer,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: night ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.80),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5A5F).withOpacity(0.20),
            blurRadius: 30,
            offset: const Offset(0, 14),
          )
        ],
      ),
      child: Center(
        child: Container(
          width: inner,
          height: inner,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFF5A5F).withOpacity(0.96),
                const Color(0xFFFF5A5F).withOpacity(0.70),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: inner * 0.22,
                    height: inner * 0.22,
                    child: const CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    count.toString().padLeft(2, '0'),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: inner * 0.32,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _AvatarDot {
  final NearbyUser user;
  final Offset center;
  final double meters;

  _AvatarDot({
    required this.user,
    required this.center,
    required this.meters,
  });
}
