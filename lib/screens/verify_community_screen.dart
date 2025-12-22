import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../routes/app_routes.dart';

class VerifyCommunityScreen extends StatefulWidget {
  const VerifyCommunityScreen({super.key});

  @override
  State<VerifyCommunityScreen> createState() => _VerifyCommunityScreenState();
}

class _VerifyCommunityScreenState extends State<VerifyCommunityScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> codeControllers =
      List.generate(5, (_) => TextEditingController());
  final List<FocusNode> focusNodes = List.generate(5, (_) => FocusNode());

  bool _isLoading = false;

  static const String _baseUrl = "http://192.168.3.25:8080";

  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(); // fondo de rombos se mueve
  }

  @override
  void dispose() {
    for (var c in codeControllers) {
      c.dispose();
    }
    for (var f in focusNodes) {
      f.dispose();
    }
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final bool keyboardOpen = media.viewInsets.bottom > 0;

    // ⏰ MODO NOCHE: desde las 19:00 hasta las 06:00
    final hour = DateTime.now().hour;
    final bool isNightMode = hour >= 19 || hour < 6;

    // 🎨 PALETA DINÁMICA (igual que login/registro)
    final Color bgColorTop =
        isNightMode ? const Color(0xFF05070A) : const Color(0xFFFFF5F5);
    final Color bgColorBottom =
        isNightMode ? const Color(0xFF0B1016) : const Color(0xFFF3F4F6);
    final Color cardColor =
        isNightMode ? const Color(0xFF0B1016) : Colors.white;
    final Color primaryText =
        isNightMode ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
    final Color secondaryText =
        isNightMode ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final Color mutedText =
        isNightMode ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);
    final Color inputFill =
        isNightMode ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    final Color inputBorder =
        isNightMode ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
    final Color cardShadowColor = isNightMode
        ? Colors.black.withOpacity(0.7)
        : Colors.black.withOpacity(0.06);
    const Color accentRed = Color(0xFFE53935);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, _) {
          return Stack(
            children: [
              // 🎨 Fondo degradado blanco/negro con rombos rojos
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      bgColorTop,
                      bgColorBottom,
                    ],
                  ),
                ),
              ),
              CustomPaint(
                painter: _MovingDiamondPainter(
                  progress: _bgController.value,
                  isNightMode: isNightMode,
                ),
                child: Container(),
              ),

              SafeArea(
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: media.viewInsets.bottom > 0
                              ? media.viewInsets.bottom + 16
                              : 24,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight:
                                size.height * (keyboardOpen ? 0.6 : 0.5),
                          ),
                          child: Container(
                            padding:
                                const EdgeInsets.fromLTRB(24, 22, 24, 20),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(32),
                                topRight: Radius.circular(32),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: cardShadowColor,
                                  blurRadius: 22,
                                  offset: const Offset(0, -10),
                                ),
                              ],
                              border: Border.all(
                                color: isNightMode
                                    ? Colors.white.withOpacity(0.08)
                                    : Colors.black.withOpacity(0.03),
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Flecha dentro del panel
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: GestureDetector(
                                    onTap: () => AppRoutes.goBack(context),
                                    child: Container(
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                        color: isNightMode
                                            ? Colors.white.withOpacity(0.05)
                                            : Colors.black.withOpacity(0.03),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isNightMode
                                              ? Colors.white.withOpacity(0.2)
                                              : Colors.black.withOpacity(0.06),
                                          width: 1.1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.2),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.arrow_back_ios_new,
                                        size: 18,
                                        color: primaryText,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                Text(
                                  "Código de la comunidad",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: primaryText,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  "Ingresa el código con el que tu comunidad fue registrada.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: secondaryText,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Cajas del código
                                Row(
                                  children: List.generate(5, (i) {
                                    return Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                        child: SizedBox(
                                          height: 56,
                                          child: TextField(
                                            controller: codeControllers[i],
                                            focusNode: focusNodes[i],
                                            textAlign: TextAlign.center,
                                            keyboardType: TextInputType.text,
                                            textCapitalization:
                                                TextCapitalization.characters,
                                            maxLength: 1,
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: primaryText,
                                            ),
                                            inputFormatters: [
                                              FilteringTextInputFormatter.allow(
                                                RegExp(r'[A-Za-z0-9]'),
                                              ),
                                            ],
                                            decoration: InputDecoration(
                                              counterText: "",
                                              filled: true,
                                              fillColor: inputFill,
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                borderSide: BorderSide(
                                                  color: inputBorder,
                                                ),
                                              ),
                                              enabledBorder:
                                                  OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                borderSide: BorderSide(
                                                  color: inputBorder,
                                                ),
                                              ),
                                              focusedBorder:
                                                  const OutlineInputBorder(
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(14),
                                                ),
                                                borderSide: BorderSide(
                                                  color: accentRed,
                                                  width: 2,
                                                ),
                                              ),
                                            ),
                                            onChanged: (val) {
                                              if (val.isNotEmpty && i < 4) {
                                                focusNodes[i + 1]
                                                    .requestFocus();
                                              } else if (val.isEmpty &&
                                                  i > 0) {
                                                focusNodes[i - 1]
                                                    .requestFocus();
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),

                                const SizedBox(height: 26),

                                // 🔴 Botón Confirmar (animado, como los otros)
                                _AnimatedPrimaryButton(
                                  label: "Confirmar",
                                  isLoading: _isLoading,
                                  onTap: _isLoading ? null : _handleConfirm,
                                ),

                                const SizedBox(height: 20),

                                Text(
                                  "Este código lo proporciona el administrador de la comunidad.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: mutedText,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  "¿Aún no tienes una comunidad registrada?",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: primaryText,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                OutlinedButton(
                                  onPressed: () => AppRoutes.navigateTo(
                                      context, AppRoutes.createCommunity),
                                  style: OutlinedButton.styleFrom(
                                    side:
                                        const BorderSide(color: accentRed),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 24),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    backgroundColor: isNightMode
                                        ? Colors.white.withOpacity(0.03)
                                        : Colors.white,
                                  ),
                                  child: const Text(
                                    "Crear comunidad",
                                    style: TextStyle(
                                      color: accentRed,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================
  //   ACCIÓN CONFIRMAR
  // ===========================================================
  Future<void> _handleConfirm() async {
    final code = codeControllers.map((c) => c.text.toUpperCase()).join();

    if (code.length != 5) {
      _show("El código debe tener 5 caracteres");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final comunidad = await _verifyCode(code);
      if (comunidad == null) {
        _show("Código inválido");
        return;
      }

      if (comunidad["estado"] != "ACTIVA") {
        _show("La comunidad aún no está activa");
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt("userId");

      if (userId == null) {
        _show("Error interno: usuario no encontrado");
        return;
      }

      final relation = await _joinCommunity(userId, code);

      if (relation == null) {
        _show("No se pudo unir a la comunidad");
        return;
      }

      final int? communityId = relation["comunidad"]?["id"];
      if (communityId != null) {
        await prefs.setInt("communityId", communityId);
      }

      if (mounted) {
        AppRoutes.navigateAndClearStack(context, AppRoutes.verifySuccess);
      }
    } catch (e) {
      _show("Error conectando con el servidor");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================== APIS ===============================

  Future<Map<String, dynamic>?> _verifyCode(String code) async {
    final response = await http
        .get(Uri.parse("$_baseUrl/api/comunidades/codigo/$code"))
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> _joinCommunity(int userId, String code) async {
    final response = await http.post(
      Uri.parse("$_baseUrl/api/comunidades/unirse/$code/usuario/$userId"),
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    return null;
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}

/// Rombos animados pero en tonos rojos (modo día/noche)
class _MovingDiamondPainter extends CustomPainter {
  final double progress; // 0..1
  final bool isNightMode;

  _MovingDiamondPainter({
    required this.progress,
    required this.isNightMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Color baseColor = isNightMode
        ? const Color(0xFFFF5A5A)
        : const Color(0xFFE53935);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = baseColor.withOpacity(isNightMode ? 0.22 : 0.14);

    const double diamondSize = 120;
    const double spacing = 90;

    final double offsetX = (progress * 40) - 20; // va y viene
    final double offsetY = (progress * 25) - 12.5;

    for (double y = -diamondSize; y < size.height + diamondSize; y += spacing) {
      for (double x = -diamondSize;
          x < size.width + diamondSize;
          x += spacing) {
        canvas.save();
        canvas.translate(
          x + diamondSize / 2 + offsetX,
          y + diamondSize / 2 + offsetY,
        );
        canvas.rotate(math.pi / 4);
        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: diamondSize,
          height: diamondSize,
        );
        final rrect =
            RRect.fromRectAndRadius(rect, const Radius.circular(26));
        canvas.drawRRect(rrect, paint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MovingDiamondPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.isNightMode != isNightMode;
}

/// Botón rojo animado tipo apps 2025 (igual que login/registro)
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
