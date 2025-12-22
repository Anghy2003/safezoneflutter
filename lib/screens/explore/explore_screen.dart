import 'package:flutter/material.dart';

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

  int _currentIndex = 2;

  bool get isNightMode {
    final hour = DateTime.now().hour;
    return hour >= 19 || hour < 7;
  }

  @override
  void initState() {
    super.initState();

    _controller = ExploreController();
    _controller.initialize(); // sesión + ubicación + cercanos + riesgo (ya lo hace)

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NearbyMapSheet(
        controller: _controller,
        night: isNightMode,
        incidentIdFromReport: incidentIdFromReport,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final night = isNightMode;

    return Scaffold(
      backgroundColor: night ? const Color(0xFF050509) : const Color(0xFFF5F5F5),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          final isLoading =
              _controller.isLoadingNearby || _controller.isLoadingLocation;

          final count = _controller.nearby.length;

          return Stack(
            children: [
              Column(
                children: [
                  _buildRadarHeader(night),
                  Expanded(
                    child: _buildRadarBody(
                      night: night,
                      isLoading: isLoading,
                      count: count,
                    ),
                  ),
                  SizedBox(height: 92 + bottomPadding),
                ],
              ),
              SafeZoneNavBar(
                currentIndex: _currentIndex,
                isNightMode: night,
                bottomPadding: bottomPadding,
                onTap: _onNavTap,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRadarHeader(bool night) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
        child: Row(
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

            // ✅ NUEVO: BADGE RIESGO (usa /api/riesgo/zona)
            RiskBadge(
              night: night,
              isLoading: _controller.isLoadingRisk,
              nivel: _controller.risk?.nivel,
              total: _controller.risk?.total,
            ),

            const Spacer(),

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
    );
  }

  Widget _buildRadarBody({
    required bool night,
    required bool isLoading,
    required int count,
  }) {
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
              const Spacer(),
              RadarView(
                count: count,
                night: night,
                isLoading: isLoading,
                controller: _pulseController,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);

    switch (index) {
      case 0:
        AppRoutes.navigateAndReplace(context, AppRoutes.home);
        break;
      case 1:
        AppRoutes.navigateAndReplace(context, AppRoutes.contacts);
        break;
      case 2:
        break;
      case 3:
        AppRoutes.navigateAndReplace(context, AppRoutes.community);
        break;
    }
  }
}
