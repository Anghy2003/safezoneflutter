import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'radar_painter.dart';

/// =============================================================
/// WIDGET REUTILIZABLE — RADAR ANIMADO
/// =============================================================
class RadarView extends StatelessWidget {
  final int count;
  final bool night;
  final bool isLoading;
  final AnimationController controller;

  const RadarView({
    super.key,
    required this.count,
    required this.night,
    required this.isLoading,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final radarSize = math.min(c.maxWidth, c.maxHeight) * 0.98;

        return Center(
          child: SizedBox(
            width: radarSize,
            height: radarSize,
            child: AnimatedBuilder(
              animation: controller,
              builder: (_, __) {
                return CustomPaint(
                  painter: RadarPainter(t: controller.value, night: night),
                  child: Center(
                    child: Container(
                      width: radarSize * 0.42,
                      height: radarSize * 0.42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFF5A5F),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF5A5F).withOpacity(0.35),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Center(
                        child: isLoading
                            ? SizedBox(
                                width: radarSize * 0.10,
                                height: radarSize * 0.10,
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
                                  fontSize: radarSize * 0.16,
                                ),
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
