// lib/screens/profile_screen.dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../service/auth_service.dart';
import '../models/usuario.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Usuario? _usuario;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  /// ✅ Importante:
  /// reconstruye headers (X-User-Id si login normal, y/o Bearer si Google)
  /// y luego recién pide /usuarios/me
  Future<void> _init() async {
    await AuthService.restoreSession();
    if (!mounted) return;
    await _loadUserFromBackend();
  }

  Future<void> _loadUserFromBackend() async {
    final result = await AuthService.backendMe();

    if (!mounted) return;

    if (result['success'] == true && result['usuario'] is Usuario) {
      setState(() {
        _usuario = result['usuario'] as Usuario;
        _isLoading = false;
      });
    } else {
      setState(() {
        _usuario = null;
        _isLoading = false;
      });

      final msg = (result['message'] ?? 'Sesión no válida').toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

      AppRoutes.navigateAndClearStack(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final nombre = _usuario?.nombre ?? 'Sin nombre';
    final email = _usuario?.email ?? 'No disponible';
    final telefono = _usuario?.telefono ?? 'No disponible';
    final tipoUsuario = _usuario?.activo == false ? 'Inactivo' : 'Miembro';
    final fotoUrl = _usuario?.fotoUrl;

    final hour = DateTime.now().hour;
    final bool isNightMode = hour >= 19 || hour < 6;

    final Color bgColor =
        isNightMode ? const Color(0xFF05070A) : const Color(0xFFF3F4F6);
    final Color cardColor =
        isNightMode ? const Color(0xFF0B1016) : Colors.white;
    final Color tileBgColor =
        isNightMode ? const Color(0xFF020617) : Colors.white;
    final Color tileBorderColor =
        isNightMode ? const Color(0xFF1F2937) : const Color(0xFFE0ECFF);
    final Color iconBgColor =
        isNightMode ? const Color(0xFF7F1D1D) : const Color(0xFFFFEBEB);
    const Color iconColor = Color(0xFFE53935);
    final Color labelColor =
        isNightMode ? const Color(0xFF9CA3AF) : Colors.grey;
    final Color valueColor =
        isNightMode ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
    final Color shadowColor = isNightMode
        ? Colors.black.withOpacity(0.7)
        : Colors.black.withOpacity(0.12);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: bgColor)),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ProfileHeader(
              nombre: nombre,
              fotoUrl: fotoUrl,
              isNightMode: isNightMode,
              onBack: () {
                AppRoutes.navigateAndReplace(context, AppRoutes.home);
              },
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 350, left: 20, right: 20),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: shadowColor,
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(
                        color: isNightMode
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.03),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildInfoTile(
                          icon: Icons.email_outlined,
                          label: "Email",
                          value: email,
                          tileBgColor: tileBgColor,
                          tileBorderColor: tileBorderColor,
                          iconBgColor: iconBgColor,
                          iconColor: iconColor,
                          labelColor: labelColor,
                          valueColor: valueColor,
                          shadowColor: shadowColor,
                        ),
                        const SizedBox(height: 16),
                        _buildInfoTile(
                          icon: Icons.phone_outlined,
                          label: "Teléfono",
                          value: telefono,
                          tileBgColor: tileBgColor,
                          tileBorderColor: tileBorderColor,
                          iconBgColor: iconBgColor,
                          iconColor: iconColor,
                          labelColor: labelColor,
                          valueColor: valueColor,
                          shadowColor: shadowColor,
                        ),
                        const SizedBox(height: 16),
                        _buildInfoTile(
                          icon: Icons.badge_outlined,
                          label: "Tipo de usuario",
                          value: tipoUsuario,
                          tileBgColor: tileBgColor,
                          tileBorderColor: tileBorderColor,
                          iconBgColor: iconBgColor,
                          iconColor: iconColor,
                          labelColor: labelColor,
                          valueColor: valueColor,
                          shadowColor: shadowColor,
                        ),
                        const SizedBox(height: 25),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _handleLogout,
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text(
                              "Cerrar sesión",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              elevation: 4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color tileBgColor,
    required Color tileBorderColor,
    required Color iconBgColor,
    required Color iconColor,
    required Color labelColor,
    required Color valueColor,
    required Color shadowColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tileBgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tileBorderColor),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconBgColor,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: labelColor)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cerrar sesión"),
        content: const Text("¿Deseas salir de tu cuenta?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () async {
              await AuthService.logout();
              if (!mounted) return;
              Navigator.pop(context);
              AppRoutes.navigateAndClearStack(context, AppRoutes.login);
            },
            child: const Text("Salir", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------
// HEADER CON OLAS + AVATAR
// -----------------------------------------------------------

class ProfileHeader extends StatelessWidget {
  final String nombre;
  final String? fotoUrl;
  final bool isNightMode;
  final VoidCallback onBack;

  const ProfileHeader({
    super.key,
    required this.nombre,
    required this.fotoUrl,
    required this.isNightMode,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 390,
      width: double.infinity,
      child: Stack(
        children: [
          _WavyBackground(isNightMode: isNightMode),
          Positioned(
            top: 36,
            left: 20,
            child: _circleButton(
              icon: Icons.arrow_back_ios_new,
              onTap: onBack,
            ),
          ),
          Positioned(
            top: 36,
            right: 20,
            child: _circleButton(
              icon: Icons.more_horiz,
              onTap: () {},
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 55),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: (fotoUrl != null && fotoUrl!.isNotEmpty)
                          ? Image.network(fotoUrl!, fit: BoxFit.cover)
                          : _defaultAvatar(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    nombre,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
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

  Widget _defaultAvatar() {
    return Container(
      color: const Color(0xFF111827),
      child: const Icon(Icons.person, size: 60, color: Colors.white70),
    );
  }
}

Widget _circleButton({
  required IconData icon,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.20),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white),
    ),
  );
}

// -----------------------------------------------------------
// OLAS ROJAS + ROMBOS
// -----------------------------------------------------------

class _WavyBackground extends StatelessWidget {
  final bool isNightMode;

  const _WavyBackground({required this.isNightMode});

  @override
  Widget build(BuildContext context) {
    final List<Color> baseBgColors = isNightMode
        ? const [Color(0xFF020617), Color(0xFF020617)]
        : const [Color(0xFF0F172A), Color(0xFF020617)];

    const List<Color> waveColors = [
      Color(0xFFFFA8A8),
      Color(0xFFFF5A5F),
      Color(0xFFE53935),
    ];

    return SizedBox(
      height: 430,
      width: double.infinity,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: baseBgColors,
              ),
            ),
          ),
          ClipPath(
            clipper: _WaveClipper(),
            child: Container(
              height: 430,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: waveColors,
                ),
              ),
              child: CustomPaint(
                painter: _DiamondPatternPainter(isNightMode: isNightMode),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    path.lineTo(0, size.height - 150);

    path.quadraticBezierTo(
      size.width * 0.25,
      size.height - 40,
      size.width * 0.5,
      size.height - 90,
    );

    path.quadraticBezierTo(
      size.width * 0.75,
      size.height - 150,
      size.width,
      size.height - 90,
    );

    path.lineTo(size.width, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(_) => false;
}

class _DiamondPatternPainter extends CustomPainter {
  final bool isNightMode;

  _DiamondPatternPainter({required this.isNightMode});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = (isNightMode
          ? Colors.white.withOpacity(0.10)
          : Colors.white.withOpacity(0.18));

    const double diamondSize = 110;
    const double spacing = 85;

    for (double y = -diamondSize; y < size.height + diamondSize; y += spacing) {
      for (double x = -diamondSize; x < size.width + diamondSize; x += spacing) {
        canvas.save();
        canvas.translate(x + diamondSize / 2, y + diamondSize / 2);
        canvas.rotate(math.pi / 4);
        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: diamondSize,
          height: diamondSize,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(25)),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
