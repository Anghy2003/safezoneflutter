import 'package:flutter/material.dart';
import '../routes/app_routes.dart';

class VerifySuccessScreen extends StatefulWidget {
  const VerifySuccessScreen({super.key});

  @override
  State<VerifySuccessScreen> createState() => _VerifySuccessScreenState();
}

class _VerifySuccessScreenState extends State<VerifySuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final bool isNightMode = hour >= 19 || hour < 6;

    // 🎨 Paleta dinámica como en login/registro
    final Color bgColor =
        isNightMode ? const Color(0xFF05070A) : const Color(0xFFF3F4F6);
    final Color cardColor =
        isNightMode ? const Color(0xFF0B1016) : Colors.white;
    final Color primaryText =
        isNightMode ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
    final Color secondaryText =
        isNightMode ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final Color cardShadowColor = isNightMode
        ? Colors.black.withOpacity(0.7)
        : Colors.black.withOpacity(0.06);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 26),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: cardShadowColor,
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(
                  color: isNightMode
                      ? Colors.white.withOpacity(0.10)
                      : Colors.black.withOpacity(0.03),
                  width: 1.2,
                ),
              ),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ✅ Ícono de éxito animado
                      Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFFF6B6B),
                                Color(0xFFE53935),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFFE53935).withOpacity(0.5),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.check_rounded,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 26),

                      // 📝 Título
                      Opacity(
                        opacity: _fadeAnimation.value,
                        child: Text(
                          "¡Todo listo!",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 🧾 Mensaje
                      Opacity(
                        opacity: _fadeAnimation.value,
                        child: Text(
                          "Te has unido correctamente a tu comunidad.\n"
                          "Ahora puedes empezar a usar SafeZone.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: secondaryText,
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // 🔴 Botón Ir al inicio (animado como en login/registro)
                      Opacity(
                        opacity: _fadeAnimation.value,
                        child: _AnimatedPrimaryButton(
                          label: "Ir al inicio",
                          isLoading: false,
                          onTap: _handleContinue,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleContinue() {
    AppRoutes.navigateAndClearStack(context, AppRoutes.home);
  }
}

/// Botón rojo animado tipo apps 2025 (igual que en login/registro)
class _AnimatedPrimaryButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback? onTap;
  final String label;

  const _AnimatedPrimaryButton({
    required this.isLoading,
    required this.onTap,
    required this.label,
  });

  @override
  State<_AnimatedPrimaryButton> createState() =>
      _AnimatedPrimaryButtonState();
}

class _AnimatedPrimaryButtonState extends State<_AnimatedPrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 0.07,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null) {
      _pressController.forward();
    }
  }

  void _onTapUp(TapUpDetails _) {
    _pressController.reverse();
  }

  void _onTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? _onTapDown : null,
      onTapUp: widget.onTap != null ? _onTapUp : null,
      onTapCancel: widget.onTap != null ? _onTapCancel : null,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pressController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: child,
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFF5A5A),
                Color(0xFFE53935),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE53935).withOpacity(0.5),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
