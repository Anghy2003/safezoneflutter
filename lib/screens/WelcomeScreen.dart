import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart'; // 👈 importar para permisos
import '../routes/app_routes.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _orbController;

  bool _pressLogin = false;
  bool _pressRegister = false;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _initLocationPermission();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _orbController.dispose();
    super.dispose();
  }

  /// 🔐 Pide los permisos de ubicación aquí (solo una vez al entrar a la app)
  Future<void> _initLocationPermission() async {
    try {
      // pequeña espera para que el contexto esté listo
      await Future.delayed(const Duration(milliseconds: 300));

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Podrías mostrar un SnackBar o dialog si quieres
        debugPrint('GPS desactivado en el dispositivo');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint(
            'Permiso de ubicación denegado permanentemente. Debe activarse en ajustes.');
        return;
      }

      if (permission == LocationPermission.denied) {
        debugPrint('Permiso de ubicación denegado por el usuario.');
        return;
      }

      // Si llegamos aquí, hay permiso concedido
      debugPrint('Permiso de ubicación concedido.');
    } catch (e) {
      debugPrint('Error solicitando permisos de ubicación: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Paleta negro + rojo + blanco
    const Color bgDark = Color(0xFF05070A);
    const Color red1 = Color(0xFFFF5A5A);
    const Color red2 = Color(0xFFE53935);

    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          // 🔴 FONDO CON DEGRADADO Y FORMAS
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgController,
              builder: (_, __) {
                final t = _bgController.value;
                return CustomPaint(
                  painter: _WelcomeBackgroundPainter(
                    progress: t,
                    red1: red1,
                    red2: red2,
                  ),
                );
              },
            ),
          ),

          // 🔴 ORB ROJO PULSANDO
          AnimatedBuilder(
            animation: _orbController,
            builder: (_, __) {
              final scale = 0.9 + (_orbController.value * 0.15);
              return Positioned(
                top: size.height * 0.16,
                right: -40,
                child: Transform.scale(
                  scale: scale,
                  child: _glowCircle(
                    diameter: 140,
                    colors: const [
                      Color(0xFFFFCDD2),
                      Color(0xFFE53935),
                    ],
                  ),
                ),
              );
            },
          ),

          // 🔴 ORB INFERIOR
          Positioned(
            bottom: -40,
            left: -20,
            child: _glowCircle(
              diameter: 180,
              colors: const [
                Color(0xFFFFEBEE),
                Color(0xFFB71C1C),
              ],
            ),
          ),

          // 🧾 TEXTOS CENTRALES
          Positioned(
            top: size.height * 0.20,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  "SafeZone",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Tu zona, tu seguridad.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.90),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  "Conéctate con tu comunidad,\nrecibe alertas y responde en segundos.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.65),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // 🔳 CARD SEMITRANSPARENTE
          Positioned(
            top: size.height * 0.38,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFF5A5A),
                          Color(0xFFE53935),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Red de emergencia activa",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Recibe avisos en tiempo real de tu comunidad.",
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.white.withOpacity(0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 🔘 BOTONES (NEGRO + ROJO)
          Positioned(
            bottom: bottomPadding + 32,
            left: 20,
            right: 20,
            child: Column(
              children: [
                // 🔴 INICIAR SESIÓN (primary)
                GestureDetector(
                  onTapDown: (_) => setState(() => _pressLogin = true),
                  onTapUp: (_) {
                    setState(() => _pressLogin = false);
                    Navigator.pushNamed(context, AppRoutes.login);
                  },
                  onTapCancel: () => setState(() => _pressLogin = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 130),
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: _pressLogin
                            ? const [red2, red1]
                            : const [red1, red2],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: red2.withOpacity(0.5),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      "Iniciar sesión",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ⚫ REGISTRARSE (negro con borde rojo)
                GestureDetector(
                  onTapDown: (_) => setState(() => _pressRegister = true),
                  onTapUp: (_) {
                    setState(() => _pressRegister = false);
                    Navigator.pushNamed(context, AppRoutes.register);
                  },
                  onTapCancel: () => setState(() => _pressRegister = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 130),
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: _pressRegister
                          ? Colors.black.withOpacity(0.65)
                          : Colors.black.withOpacity(0.45),
                      border: Border.all(
                        color: const Color(0xFFE53935),
                        width: 1.4,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      "Crear cuenta",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  "Al continuar aceptas nuestras políticas de seguridad.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowCircle({
    required double diameter,
    required List<Color> colors,
  }) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: colors,
          center: Alignment.topLeft,
          radius: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withOpacity(0.5),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
    );
  }
}

// 🎨 Fondo con diagonales y “ondas” rojas / negras
class _WelcomeBackgroundPainter extends CustomPainter {
  final double progress;
  final Color red1;
  final Color red2;

  _WelcomeBackgroundPainter({
    required this.progress,
    required this.red1,
    required this.red2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint();

    // Fondo base negro
    p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF05070A),
        Color(0xFF000000),
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), p);

    // Franja diagonal suave
    final pathDiagonal = Path();
    pathDiagonal.moveTo(0, size.height * 0.15);
    pathDiagonal.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.05,
      size.width,
      size.height * 0.22,
    );
    pathDiagonal.lineTo(size.width, size.height * 0.55);
    pathDiagonal.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.65,
      0,
      size.height * 0.52,
    );
    pathDiagonal.close();

    p.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withOpacity(0.03),
        Colors.white.withOpacity(0.00),
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(pathDiagonal, p);

    // Ondas rojas muy suaves en la parte inferior
    _drawRedWave(
      canvas,
      size,
      baseY: size.height * 0.85,
      amplitude: 22,
      opacity: 0.18,
    );
    _drawRedWave(
      canvas,
      size,
      baseY: size.height * 0.78,
      amplitude: 26,
      opacity: 0.10,
    );
  }

  void _drawRedWave(
    Canvas canvas,
    Size size, {
    required double baseY,
    required double amplitude,
    required double opacity,
  }) {
    final path = Path();
    final double waveLength = size.width;
    final double offset = progress * waveLength * 2;

    path.moveTo(0, baseY);

    for (double x = 0; x <= size.width; x++) {
      final y = baseY +
          amplitude *
              math.sin(
                (x / waveLength * 2 * math.pi) + (offset / waveLength),
              );
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          red1.withOpacity(opacity),
          red2.withOpacity(0.0),
        ],
      ).createShader(
          Rect.fromLTWH(0, baseY - amplitude, size.width, size.height - baseY));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WelcomeBackgroundPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
