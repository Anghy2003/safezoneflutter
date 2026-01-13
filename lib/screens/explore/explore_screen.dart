// lib/screens/explore/explore_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../routes/app_routes.dart';
import '../../widgets/safezone_nav_bar.dart';

import 'explore_controller.dart';
import 'widgets/nearby_map_sheet.dart';
import 'widgets/radar_view.dart';
import 'widgets/risk_badge.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  late final ExploreController _controller;
  late final AnimationController _pulseController;

  // ✅ 4 items: Home, Explorar, Comunidades, Menú
  int _currentIndex = 1;

  // ✅ header cache fallback
  String? _cachedPhotoUrl;
  String? _cachedDisplayName;

  bool get _night => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();

    _controller = ExploreController();
    _controller.initialize();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _loadHeaderFromPrefs();
  }

  Future<void> _loadHeaderFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final photo = (prefs.getString('photoUrl') ?? '').trim();
      final name = (prefs.getString('displayName') ?? '').trim();

      if (!mounted) return;
      setState(() {
        _cachedPhotoUrl = photo.isNotEmpty ? photo : null;
        _cachedDisplayName = name.isNotEmpty ? name : null;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _openMapModal() {
    final args = ModalRoute.of(context)?.settings.arguments;

    final incidentIdFromReport =
        (args is Map && args['incidenteId'] != null)
            ? args['incidenteId'].toString()
            : null;

    final night = _night;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NearbyMapSheet(
        controller: _controller,
        night: night,
        incidentIdFromReport: incidentIdFromReport,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final night = _night;

    // ✅ prefer controller, fallback a cache
    final photoUrl = (_controller.photoUrl ?? '').trim().isNotEmpty
        ? _controller.photoUrl
        : _cachedPhotoUrl;

    final displayName = (_controller.displayName ?? '').trim().isNotEmpty
        ? _controller.displayName
        : (_cachedDisplayName ?? "Mi cuenta");

    return Scaffold(
      backgroundColor: night ? const Color(0xFF050509) : const Color(0xFFF5F5F5),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final isLoading =
              _controller.isLoadingNearby || _controller.isLoadingLocation;

          return Stack(
            children: [
              Column(
                children: [
                  _buildRadarHeader(night),
                  Expanded(
                    child: _buildRadarBody(
                      night: night,
                      isLoading: isLoading,
                    ),
                  ),
                  const SizedBox(height: 92),
                ],
              ),

              SafeZoneNavBar(
                currentIndex: _currentIndex,
                isNightMode: night,
                photoUrl: photoUrl,
                onTap: (i) => _onNavTap(i, photoUrl, displayName!),
                bottomExtra: 0,
              ),
            ],
          );
        },
      ),
    );
  }

  /// ✅ HEADER: ahora es horizontal-scroll para evitar overflow (RenderFlex)
  Widget _buildRadarHeader(bool night) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.radar, color: Color(0xFFFF5A5F), size: 18),
              const SizedBox(width: 8),
              Text(
                "Radar",
                style: TextStyle(
                  color: night ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),

              RiskBadge(
                night: night,
                isLoading: _controller.isLoadingRisk,
                nivel: _controller.risk?.nivel,
                total: _controller.risk?.total,
              ),

              const SizedBox(width: 10),

              if (_controller.isOffline)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: Colors.orangeAccent.withOpacity(0.8)),
                  ),
                  child: const Text(
                    "OFFLINE",
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),

              const SizedBox(width: 10),

              TextButton.icon(
                onPressed: _openMapModal,
                icon: Icon(
                  Icons.map_outlined,
                  size: 18,
                  color: night ? Colors.white : Colors.black,
                ),
                label: Text(
                  "Ver mapa",
                  style: TextStyle(
                    color: night ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  backgroundColor: night
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.04),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadarBody({
    required bool night,
    required bool isLoading,
  }) {
    final count = _controller.nearby.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: Container(
        decoration: BoxDecoration(
          color: night ? const Color(0xFF0B0F14) : Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            children: [
              Text(
                "Zona de personas cercanas",
                style: TextStyle(
                  color: night ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Descubre quién está dentro de tu radio de seguridad.",
                style: TextStyle(
                  color: night ? Colors.white60 : Colors.black54,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),

              if (_controller.errorNearby != null)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: night
                        ? Colors.red.withOpacity(0.14)
                        : Colors.red.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.redAccent.withOpacity(0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _controller.errorNearby!,
                          style: TextStyle(
                            color: night ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const Spacer(),

              RadarView(
                users: _controller.nearby,
                center: _controller.center,
                radarMeters: _controller.radioMeters,
                night: night,
                isLoading: isLoading,
                controller: _pulseController,
              ),

              const SizedBox(height: 12),

              Text(
                isLoading ? "Buscando..." : "Personas detectadas: $count",
                style: TextStyle(
                  color: night ? Colors.white60 : Colors.black54,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // NAV: 0 Home, 1 Explore, 2 Communities, 3 Menu(pantalla)
  // =========================================================
  void _onNavTap(int index, String? photoUrl, String displayName) {
    if (index == 3) {
      AppRoutes.navigateTo(
        context,
        AppRoutes.menu,
        arguments: {
          "photoUrl": photoUrl,
          "displayName": displayName,
        },
      );
      return;
    }

    if (index == _currentIndex) return;

    setState(() => _currentIndex = index);

    switch (index) {
      case 0:
        AppRoutes.navigateAndReplace(context, AppRoutes.home);
        break;
      case 1:
        break;
      case 2:
        AppRoutes.navigateAndReplace(context, AppRoutes.community);
        break;
    }
  }
}
