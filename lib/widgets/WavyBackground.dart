import 'package:flutter/material.dart';
import 'dart:math' as math;

class WavyBackground extends StatefulWidget {
  final Widget child;
  final Color primaryColor;
  final Color secondaryColor;
  
  const WavyBackground({
    super.key,
    required this.child,
    this.primaryColor = const Color(0xFF5B9BD5), // Azul cielo brillante
    this.secondaryColor = const Color(0xFF7CB3E8), // Azul claro
  });

  @override
  State<WavyBackground> createState() => _WavyBackgroundState();
}

class _WavyBackgroundState extends State<WavyBackground>
    with TickerProviderStateMixin {
  late AnimationController _controller1;
  late AnimationController _controller2;
  late AnimationController _controller3;

  @override
  void initState() {
    super.initState();
    
    _controller1 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _controller2 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _controller3 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    _controller3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Fondo base con gradiente
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                widget.primaryColor,
                widget.secondaryColor,
              ],
            ),
          ),
        ),
        
        // Ondas animadas
        AnimatedBuilder(
          animation: Listenable.merge([_controller1, _controller2, _controller3]),
          builder: (context, child) {
            return CustomPaint(
              painter: WavePainter(
                animation1: _controller1.value,
                animation2: _controller2.value,
                animation3: _controller3.value,
                waveColor1: Colors.white.withOpacity(0.1),
                waveColor2: Colors.white.withOpacity(0.08),
                waveColor3: Colors.white.withOpacity(0.05),
              ),
              child: Container(),
            );
          },
        ),
        
        // Contenido
        widget.child,
      ],
    );
  }
}

class WavePainter extends CustomPainter {
  final double animation1;
  final double animation2;
  final double animation3;
  final Color waveColor1;
  final Color waveColor2;
  final Color waveColor3;

  WavePainter({
    required this.animation1,
    required this.animation2,
    required this.animation3,
    required this.waveColor1,
    required this.waveColor2,
    required this.waveColor3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Primera onda (superior)
    _drawWave(
      canvas,
      size,
      waveColor1,
      animation1,
      size.height * 0.3,
      30,
      2.0,
    );

    // Segunda onda (media)
    _drawWave(
      canvas,
      size,
      waveColor2,
      animation2,
      size.height * 0.5,
      40,
      1.5,
    );

    // Tercera onda (inferior)
    _drawWave(
      canvas,
      size,
      waveColor3,
      animation3,
      size.height * 0.7,
      35,
      1.8,
    );
  }

  void _drawWave(
    Canvas canvas,
    Size size,
    Color color,
    double animation,
    double yPosition,
    double amplitude,
    double frequency,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final waveLength = size.width;
    final offset = animation * waveLength;

    path.moveTo(0, yPosition);

    for (double x = 0; x <= size.width; x++) {
      final y = yPosition +
          amplitude *
              math.sin((x / waveLength * frequency * 2 * math.pi) +
                  (offset / waveLength * 2 * math.pi));
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) => true;
}