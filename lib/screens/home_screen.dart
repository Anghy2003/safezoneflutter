// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

import '../routes/app_routes.dart';
import '../service/auth_service.dart';
import '../service/sos_hardware_service.dart';
import '../models/usuario.dart';
import 'emergency_report_screen.dart';
import '../widgets/safezone_nav_bar.dart';
import '../widgets/safety_tips_carousel.dart';

class ApiConfig {
  static const String baseUrl = 'http://192.168.3.25:8080/api';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  String? _photoUrl;
  String? _communityName;
  String _locationLabel = 'Ubicación no disponible';

  int? _userId;
  int? _communityId;

  Position? _currentPosition;

  bool get isNightMode {
    final hour = DateTime.now().hour;
    return hour >= 19 || hour < 7;
  }

  late AnimationController _sosController;

  @override
  void initState() {
    super.initState();
    _loadUserDataFromBackend();
    _loadLocation();

    _sosController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _sosController.dispose();
    super.dispose();
  }

  // =========================================================
  // ✅ NUEVO: mapear tipo -> icon/color y abrir reporte desde carrusel
  // =========================================================
  IconData _iconFromType(String type) {
    switch (type.toLowerCase()) {
      case "médica":
      case "medica":
        return Icons.local_hospital_outlined;
      case "fuego":
        return Icons.local_fire_department_outlined;
      case "desastre":
        return Icons.domain_outlined;
      case "accidente":
        return Icons.car_crash;
      case "violencia":
        return Icons.flash_on_outlined;
      case "robo":
        return Icons.person_off_outlined;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  Color _colorFromType(String type) {
    switch (type.toLowerCase()) {
      case "médica":
      case "medica":
        return const Color(0xFF4CC9A6);
      case "fuego":
        return const Color(0xFFFF6B6B);
      case "desastre":
        return const Color(0xFF5C9ECC);
      case "accidente":
        return const Color(0xFFB574F0);
      case "violencia":
        return const Color(0xFFF06292);
      case "robo":
        return const Color(0xFFF7D774);
      default:
        return const Color(0xFFFF5A5F);
    }
  }

  void _openEmergencyFromTip(String type) {
    final icon = _iconFromType(type);
    final color = _colorFromType(type);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmergencyReportScreen(
          emergencyType: type,
          icon: icon,
          colors: [color, color],
          usuarioId: _userId,
          comunidadId: _communityId,
          initialLat: _currentPosition?.latitude,
          initialLng: _currentPosition?.longitude,
          source: 'CAROUSEL_TIP',
        ),
      ),
    );
  }

  // =========================================================
  // ✅ FIX DEFINITIVO: no exigir /usuarios/me para LEGACY
  // =========================================================
  Future<void> _loadUserDataFromBackend() async {
    try {
      // Reconstruye sesión (userId, authMode, etc.)
      await AuthService.restoreSession();

      final userId = await AuthService.getCurrentUserId();
      final communityId = await AuthService.getCurrentCommunityId();

      // 1) Si no hay sesión -> login
      if (userId == null) {
        if (!mounted) return;
        AppRoutes.navigateAndClearStack(context, AppRoutes.login);
        return;
      }

      // 2) LEGACY: NO llames backendMe() (te rebotaba)
      if (AuthService.authMode == 'legacy') {
        if (!mounted) return;
        setState(() {
          _userId = userId;
          _communityId = communityId;
          _communityName = _communityName ?? 'Mi comunidad';
          // _photoUrl queda null si no la tienes en prefs (puedes cargarla luego si quieres)
        });
        return;
      }

      // 3) GOOGLE: aquí sí usa /usuarios/me (FirebasePrincipal)
      final result = await AuthService.backendMe();
      if (!mounted) return;

      if (result['success'] == true && result['usuario'] is Usuario) {
        final usuario = result['usuario'] as Usuario;

        setState(() {
          _photoUrl = usuario.fotoUrl;
          _userId = usuario.id ?? userId;
          _communityId = usuario.comunidadId ?? communityId;

          final backendName = usuario.comunidadNombre;
          _communityName = (backendName != null && backendName.trim().isNotEmpty)
              ? backendName.trim()
              : (_communityName ?? 'Mi comunidad');
        });
      } else {
        // Si en google falla /me, sesión inválida
        if (!mounted) return;
        AppRoutes.navigateAndClearStack(context, AppRoutes.login);
      }
    } catch (e) {
      debugPrint('Error cargando usuario desde backend: $e');
      // Opcional: si quieres forzar login ante error crítico
      // if (mounted) AppRoutes.navigateAndClearStack(context, AppRoutes.login);
    }
  }

  Future<void> _sendLocationToBackend() async {
    if (_userId == null || _currentPosition == null) return;

    try {
      final uri = Uri.parse("${ApiConfig.baseUrl}/ubicaciones-usuario/actual")
          .replace(queryParameters: {
        "usuarioId": _userId.toString(),
        "lat": _currentPosition!.latitude.toString(),
        "lng": _currentPosition!.longitude.toString(),
        "precision": _currentPosition!.accuracy.round().toString(),
      });

      final resp = await http.post(uri, headers: AuthService.headers);

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        debugPrint("Ubicación actualizada correctamente");
      } else {
        debugPrint("Error enviando ubicación: ${resp.statusCode} → ${resp.body}");
      }
    } catch (e) {
      debugPrint("Error de red al enviar ubicación: $e");
    }
  }

  Future<void> _loadLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) setState(() => _locationLabel = "GPS desactivado");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _locationLabel = "Permiso de ubicación no concedido");
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _currentPosition = pos;
      _sendLocationToBackend();

      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );

      if (!mounted) return;

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        setState(() {
          _locationLabel = p.subLocality?.isNotEmpty == true
              ? p.subLocality!
              : p.locality ?? "Ubicación actual";
        });
      }
    } catch (e) {
      if (mounted) setState(() => _locationLabel = "Error obteniendo ubicación");
    }
  }

  Future<void> _handleSOS() async {
    await SosHardwareService.enviarSOSDesdeUI();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("SOS enviado"),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) return;

    setState(() => _currentIndex = index);

    switch (index) {
      case 0:
        break;
      case 1:
        AppRoutes.navigateAndReplace(context, AppRoutes.contacts);
        break;
      case 2:
        AppRoutes.navigateAndReplace(context, AppRoutes.explore);
        break;
      case 3:
        AppRoutes.navigateAndReplace(context, AppRoutes.community);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final bool night = isNightMode;

    final Color scaffoldBg =
        night ? const Color(0xFF050509) : const Color(0xFFFDF7F7);
    final Color cardBg = night ? const Color(0xFF13151D) : Colors.white;
    final Color cardText = night ? Colors.white : const Color(0xFF222222);
    final Color subtleText = night ? Colors.white70 : Colors.grey.shade700;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: night ? const Color(0xFF181A24) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(night ? 0.45 : 0.12),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            AppRoutes.navigateTo(context, AppRoutes.profile);
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFFF5A5F),
                                width: 2,
                              ),
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withOpacity(night ? 0.5 : 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: (_photoUrl != null &&
                                      _photoUrl!.trim().isNotEmpty)
                                  ? Image.network(_photoUrl!, fit: BoxFit.cover)
                                  : const Icon(
                                      Icons.person,
                                      size: 22,
                                      color: Color(0xFFFF5A5F),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _communityName ?? "Sin comunidad",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: cardText,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: Color(0xFFFF5A5F),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _locationLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: subtleText,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {},
                          icon: Icon(
                            Icons.notifications_outlined,
                            size: 20,
                            color: subtleText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SafetyTipsCarousel(
                          nightMode: night,
                          onTipTap: (tip) => _openEmergencyFromTip(tip.title),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(18, 22, 18, 26),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withOpacity(night ? 0.4 : 0.10),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              GestureDetector(
                                onLongPress: _handleSOS,
                                child: AnimatedBuilder(
                                  animation: _sosController,
                                  builder: (context, child) {
                                    final scale = 1 +
                                        0.06 *
                                            (_sosController.value - 0.5).abs() *
                                            2;
                                    return Transform.scale(
                                      scale: scale,
                                      child: child,
                                    );
                                  },
                                  child: Container(
                                    width: 170,
                                    height: 170,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          Color(0xFFFFA07A),
                                          Color(0xFFFF5A5F),
                                          Color(0xFFE53935),
                                        ],
                                        center: Alignment(-0.2, -0.3),
                                        radius: 0.95,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0x66FF5A5F),
                                          blurRadius: 30,
                                          spreadRadius: 10,
                                          offset: Offset(0, 12),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        Text(
                                          "SOS",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 34,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          "Mantén 3 segundos",
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "Mantén presionado para enviar una alerta a tu red.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: subtleText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "¿Cuál es tu emergencia?",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: cardText,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildEmergencyChips(night),
                        SizedBox(height: 110 + bottomPadding),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeZoneNavBar(
            currentIndex: _currentIndex,
            isNightMode: night,
            bottomPadding: bottomPadding,
            onTap: _onNavTap,
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyChips(bool night) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _chip("Médica", Icons.local_hospital_outlined, const Color(0xFF4CC9A6),
            night),
        _chip("Fuego", Icons.local_fire_department_outlined,
            const Color(0xFFFF6B6B), night),
        _chip("Desastre", Icons.domain_outlined, const Color(0xFF5C9ECC), night),
        _chip("Accidente", Icons.car_crash, const Color(0xFFB574F0), night),
        _chip("Violencia", Icons.flash_on_outlined, const Color(0xFFF06292),
            night),
        _chip("Robo", Icons.person_off_outlined, const Color(0xFFF7D774), night),
      ],
    );
  }

  Widget _chip(String text, IconData icon, Color color, bool night) {
    return GestureDetector(
      onTap: () => _handleEmergencyType(text, icon, [color, color]),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: night ? const Color(0xFF181A24) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withOpacity(0.65), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(night ? 0.45 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.15),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: night ? Colors.white : const Color(0xFF222222),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleEmergencyType(String type, IconData icon, List<Color> colors) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmergencyReportScreen(
          emergencyType: type,
          icon: icon,
          colors: colors,
          usuarioId: _userId,
          comunidadId: _communityId,
          initialLat: _currentPosition?.latitude,
          initialLng: _currentPosition?.longitude,
          source: 'BOTON_EMERGENCIA',
        ),
      ),
    );
  }
}
