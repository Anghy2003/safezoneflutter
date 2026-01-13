// lib/screens/welcome_screen.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:another_telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../routes/app_routes.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bgController;
  late final AnimationController _orbController;

  bool _pressLogin = false;
  bool _pressRegister = false;

  static const String _kAskedSmsPermission = "asked_sms_permission_v1";

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

    // ✅ Pedimos permisos cuando ya existe UI
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initLocationPermission();
      await _initSmsPermissionOnce();
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _orbController.dispose();
    super.dispose();
  }

  /// 🔐 Ubicación
  Future<void> _initLocationPermission() async {
    try {
      await Future.delayed(const Duration(milliseconds: 250));

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('GPS desactivado en el dispositivo');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint(
          'Permiso de ubicación denegado permanentemente. Debe activarse en ajustes.',
        );
        return;
      }

      if (permission == LocationPermission.denied) {
        debugPrint('Permiso de ubicación denegado por el usuario.');
        return;
      }

      debugPrint('Permiso de ubicación concedido.');
    } catch (e) {
      debugPrint('Error solicitando permisos de ubicación: $e');
    }
  }

  /// ✅ SMS (ANDROID): pedir permiso solo una vez
  /// para permitir envío directo (SIM/saldo) en emergencias.
  Future<void> _initSmsPermissionOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final askedBefore = prefs.getBool(_kAskedSmsPermission) ?? false;
      if (askedBefore) return;

      // ✅ Marca como “ya preguntamos” (no molesta cada vez)
      await prefs.setBool(_kAskedSmsPermission, true);

      if (!mounted) return;

      final allow = await _showSmsPermissionDialog();
      if (!allow) {
        debugPrint("Usuario rechazó el diálogo previo de permiso SMS.");
        return;
      }

      final telephony = Telephony.instance;

      // (Opcional) verifica si el dispositivo soporta SMS
      final canSend = (await telephony.isSmsCapable) ?? false;
      if (!canSend) {
        debugPrint("Dispositivo NO soporta SMS.");
        return;
      }

      // ✅ another_telephony: pedir SOLO permisos de SMS (no PHONE)
      final bool? granted = await telephony.requestSmsPermissions;
      if (granted == true) {
        debugPrint("Permiso SEND_SMS concedido.");
      } else {
        debugPrint("Permiso SEND_SMS denegado.");
      }
    } catch (e) {
      debugPrint("Error solicitando permiso SMS: $e");
    }
  }

  Future<bool> _showSmsPermissionDialog() async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0E1322) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            "Permiso para SMS",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
            ),
          ),
          content: Text(
            "SafeZone puede enviar un SMS automático a tus contactos en una emergencia, "
            "sin abrir apps y sin que tengas que presionar “Enviar”.\n\n"
            "Esto usa tu saldo/plan de SMS del operador.\n\n"
            "¿Deseas habilitarlo?",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFA9B1C3) : const Color(0xFF475569),
              height: 1.35,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Ahora no"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                "Habilitar",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );

    return res == true;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    const Color red1 = Color(0xFFFF5A5A);
    const Color red2 = Color(0xFFE53935);

    final Color bgColor =
        isDark ? const Color(0xFF05070A) : const Color(0xFFF3F4F6);

    final Color primaryText =
        isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827);

    final Color subtitleText = isDark
        ? Colors.white.withOpacity(0.90)
        : const Color(0xFF374151);

    final Color secondaryText = isDark
        ? Colors.white.withOpacity(0.65)
        : const Color(0xFF6B7280);

    final Color glassFill = isDark
        ? Colors.white.withOpacity(0.03)
        : Colors.white.withOpacity(0.86);

    final Color glassBorder = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.06);

    final Color backBtnFill = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.06);

    final Color backBtnBorder = isDark
        ? Colors.white.withOpacity(0.40)
        : Colors.black.withOpacity(0.10);

    final Color backIconColor = isDark ? Colors.white : const Color(0xFF111827);

    final Color shadowColor =
        isDark ? Colors.black.withOpacity(0.45) : Colors.black.withOpacity(0.06);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
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
                    isDark: isDark,
                  ),
                );
              },
            ),
          ),

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
                    colors: isDark
                        ? const [Color(0xFFFFCDD2), Color(0xFFE53935)]
                        : const [Color(0xFFFFEBEE), Color(0xFFE53935)],
                    glowOpacity: isDark ? 0.50 : 0.22,
                  ),
                ),
              );
            },
          ),

          Positioned(
            bottom: -40,
            left: -20,
            child: _glowCircle(
              diameter: 180,
              colors: isDark
                  ? const [Color(0xFFFFEBEE), Color(0xFFB71C1C)]
                  : const [Color(0xFFFFCDD2), Color(0xFFE53935)],
              glowOpacity: isDark ? 0.50 : 0.20,
            ),
          ),

          Positioned(
            top: size.height * 0.20,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  "SafeZone",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: primaryText,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Tu zona, tu seguridad.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: subtitleText,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  "Conéctate con tu comunidad,\nrecibe alertas y responde en segundos.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: secondaryText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            top: size.height * 0.38,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              decoration: BoxDecoration(
                color: glassFill,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: glassBorder, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
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
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [red1, red2]),
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
                        Text(
                          "Red de emergencia activa",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: primaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Recibe avisos en tiempo real de tu comunidad.",
                          style: TextStyle(
                            fontSize: 11.5,
                            color: secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            bottom: bottomPadding + 32,
            left: 20,
            right: 20,
            child: Column(
              children: [
                // LOGIN
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
                          color: red2.withOpacity(isDark ? 0.50 : 0.22),
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

                // REGISTRO
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
                      color: isDark
                          ? (_pressRegister
                              ? Colors.black.withOpacity(0.65)
                              : Colors.black.withOpacity(0.45))
                          : (_pressRegister
                              ? Colors.white.withOpacity(0.90)
                              : Colors.white.withOpacity(0.98)),
                      border: Border.all(color: red2, width: 1.4),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "Crear cuenta",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  "Al continuar aceptas nuestras políticas de seguridad.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: secondaryText),
                ),
              ],
            ),
          ),

          // Back
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: backBtnFill,
                  shape: BoxShape.circle,
                  border: Border.all(color: backBtnBorder),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: backIconColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowCircle({
    required double diameter,
    required List<Color> colors,
    required double glowOpacity,
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
            color: colors.last.withOpacity(glowOpacity),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
    );
  }
}

class _WelcomeBackgroundPainter extends CustomPainter {
  final double progress;
  final Color red1;
  final Color red2;
  final bool isDark;

  _WelcomeBackgroundPainter({
    required this.progress,
    required this.red1,
    required this.red2,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint();

    p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? const [Color(0xFF05070A), Color(0xFF000000)]
          : const [Color(0xFFF3F4F6), Color(0xFFFFFFFF)],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), p);

    final pathDiagonal = Path()
      ..moveTo(0, size.height * 0.15)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.05,
        size.width,
        size.height * 0.22,
      )
      ..lineTo(size.width, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.65,
        0,
        size.height * 0.52,
      )
      ..close();

    final Color diagA =
        isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03);
    final Color diagB =
        isDark ? Colors.white.withOpacity(0.00) : Colors.black.withOpacity(0.00);

    p.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [diagA, diagB],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(pathDiagonal, p);

    _drawRedWave(
      canvas,
      size,
      baseY: size.height * 0.85,
      amplitude: 22,
      opacity: isDark ? 0.18 : 0.10,
    );

    _drawRedWave(
      canvas,
      size,
      baseY: size.height * 0.78,
      amplitude: 26,
      opacity: isDark ? 0.10 : 0.06,
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
              math.sin((x / waveLength * 2 * math.pi) + (offset / waveLength));
      path.lineTo(x, y);
    }

    path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          red1.withOpacity(opacity),
          red2.withOpacity(0.0),
        ],
      ).createShader(
        Rect.fromLTWH(0, baseY - amplitude, size.width, size.height - baseY),
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WelcomeBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}
