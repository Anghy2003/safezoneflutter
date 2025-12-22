import 'dart:async';
import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../service/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    // ⏳ Mantén el splash visible (pero decide ruta según sesión)
    _timer = Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;

      // restoreSession() ya corre en main(), pero si quieres blindarlo:
      // await AuthService.restoreSession();

      final userId = await AuthService.getCurrentUserId();

      // ✅ Si NO hay sesión -> flujo normal (welcome)
      if (userId == null) {
        if (!mounted) return;
        AppRoutes.navigateAndClearStack(context, AppRoutes.welcome);
        return;
      }

      // ✅ Hay sesión -> entrar directo
      final communityId = await AuthService.getCurrentCommunityId();
      if (!mounted) return;

      if (communityId == null) {
        AppRoutes.navigateAndClearStack(context, AppRoutes.verifyCommunity);
      } else {
        AppRoutes.navigateAndClearStack(context, AppRoutes.home);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color bgDark = Color(0xFF05070A);
    const Color red1 = Color(0xFFFF5A5A);
    const Color red2 = Color(0xFFE53935);

    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          // Degradado de fondo
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF05070A),
                  Color(0xFF000000),
                ],
              ),
            ),
          ),

          // Glow rojo atrás
          Positioned(
            bottom: -80,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    red2.withOpacity(0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacity.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // LOGO
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [red1, red2],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: red2.withOpacity(0.6),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Image.asset(
                        "assets/images/logoblanco.png",
                        width: 64,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "SafeZone",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
