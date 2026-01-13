// lib/screens/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../routes/app_routes.dart';
import '../service/auth_service.dart';

// ✅ NUEVO: guard de penalización y bandera de políticas
import '../service/abuse_guard_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  Timer? _timer;

  static const String kPoliciesAccepted = "policies_accepted_v1";

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

    _timer = Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;

      // ✅ 0) Gate: penalización
      final penalized = await AbuseGuardService.isPenalized();
      if (!mounted) return;
      if (penalized) {
        AppRoutes.navigateAndClearStack(context, AppRoutes.penalized);
        return;
      }

      // ✅ 1) Gate: políticas (ANTES de todo)
      final prefs = await SharedPreferences.getInstance();
      final accepted = prefs.getBool(kPoliciesAccepted) ?? false;
      if (!mounted) return;

      if (!accepted) {
        AppRoutes.navigateAndClearStack(context, AppRoutes.policies);
        return;
      }

      // ✅ 2) Flujo original
      await AuthService.restoreSession();

      final userId = await AuthService.getCurrentUserId();

      if (userId == null) {
        if (!mounted) return;
        AppRoutes.navigateAndClearStack(context, AppRoutes.welcome);
        return;
      }

      final communityId = await AuthService.getCurrentCommunityId();
      if (!mounted) return;

      if (communityId == null) {
        AppRoutes.navigateAndClearStack(context, AppRoutes.myCommunities);
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    const Color red1 = Color(0xFFFF5A5A);
    const Color red2 = Color(0xFFE53935);

    final Gradient bgGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF05070A), Color(0xFF000000)],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF5F5),
              Color(0xFFFFEBEE),
              Color(0xFFFFFFFF),
            ],
          );

    final double glowOpacity = isDark ? 0.55 : 0.18;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF111827);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF05070A) : const Color(0xFFFFF5F5),
      body: Stack(
        children: [
          Container(decoration: BoxDecoration(gradient: bgGradient)),
          Positioned(
            bottom: -80,
            right: -40,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    red2.withOpacity(glowOpacity),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          if (!isDark)
            Positioned(
              top: -70,
              left: -50,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      red1.withOpacity(0.14),
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
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [red1, red2]),
                      boxShadow: [
                        BoxShadow(
                          color: red2.withOpacity(isDark ? 0.60 : 0.25),
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
                  Text(
                    "SafeZone",
                    style: TextStyle(
                      color: titleColor,
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
