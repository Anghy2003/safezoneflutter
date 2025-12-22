import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../explore_controller.dart';
import '../explore_models.dart';

import 'nearby_list.dart';
import 'selected_user_card.dart';
import 'risk_badge.dart';

class NearbyMapSheet extends StatefulWidget {
  final ExploreController controller;
  final bool night;
  final String? incidentIdFromReport;

  const NearbyMapSheet({
    super.key,
    required this.controller,
    required this.night,
    required this.incidentIdFromReport,
  });

  @override
  State<NearbyMapSheet> createState() => _NearbyMapSheetState();
}

class _NearbyMapSheetState extends State<NearbyMapSheet> {
  late final MapController _map;
  bool _mapReady = false;

  bool _showList = false;
  int _mapStyleIndex = 0;

  bool _autoRouteRequested = false;

  final List<Map<String, String>> _mapStyles = [
    {'name': 'Clásico', 'url': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'},
    {'name': 'Humanitario', 'url': 'https://tile-a.openstreetmap.fr/hot/{z}/{x}/{y}.png'},
    {'name': 'Oscuro', 'url': 'https://cartodb-basemaps-a.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png'},
  ];

  @override
  void initState() {
    super.initState();
    _map = MapController();
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_autoRouteRequested && widget.incidentIdFromReport != null) {
      _autoRouteRequested = true;
      _loadRouteToIncident();
    }
  }

  Future<void> _loadRouteToIncident() async {
    final id = widget.incidentIdFromReport;
    if (id == null) return;

    await widget.controller.loadRouteToIncident(id);

    final pts = widget.controller.routePoints;
    if (_mapReady && pts.isNotEmpty) {
      _map.move(pts.first, 17.0);
    }
  }

  void _clearRoute() {
    widget.controller.clearRoute();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final night = widget.night;
    final ctrl = widget.controller;

    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: night ? const Color(0xFF050509) : const Color(0xFFF5F5F5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        child: Column(
          children: [
            _buildHeader(top, night),
            _buildTitle(ctrl, night),
            const SizedBox(height: 10),
            _buildBody(ctrl, night, bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double top, bool night) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 10 + top * 0.15, 14, 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: night ? Colors.white24 : Colors.black26,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close, color: night ? Colors.white : Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(ExploreController ctrl, bool night) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: night
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Icon(Icons.map_outlined,
                    color: night ? Colors.white : Colors.black),
                const SizedBox(width: 8),
                Text(
                  "Mapa de cercanos",
                  style: TextStyle(
                    color: night ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // ✅ NUEVO: riesgo en el modal también
          RiskBadge(
            night: night,
            isLoading: ctrl.isLoadingRisk,
            nivel: ctrl.risk?.nivel,
            total: ctrl.risk?.total,
          ),

          const Spacer(),

          Text(
            ctrl.isLoadingNearby ? "Buscando..." : "Usuarios: ${ctrl.nearby.length}",
            style: TextStyle(
              color: night ? Colors.white70 : Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ExploreController ctrl, bool night, double bottom) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 0, 14, 14 + bottom),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              _buildMap(ctrl, night),
              _buildTopControls(ctrl, night),

              if (ctrl.errorNearby != null) _buildError(ctrl.errorNearby!, night),

              if (_showList) _buildList(ctrl, night),

              if (ctrl.selectedUser != null && !_showList)
                _buildSelectedCard(ctrl, night),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMap(ExploreController ctrl, bool night) {
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: ctrl.center,
        initialZoom: 16,
        onMapReady: () {
          _mapReady = true;
          setState(() => _map.move(ctrl.center, 16));
        },
      ),
      children: [
        TileLayer(
          urlTemplate: _mapStyles[_mapStyleIndex]['url']!,
          userAgentPackageName: "com.safezone.app",
        ),

        CircleLayer(
          circles: [
            CircleMarker(
              point: ctrl.center,
              radius: ctrl.radioMeters,
              useRadiusInMeter: true,
              color: const Color(0xFFFF5A5F).withOpacity(0.10),
              borderColor: const Color(0xFFFF5A5F).withOpacity(0.45),
              borderStrokeWidth: 2,
            ),
          ],
        ),

        if (ctrl.routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: ctrl.routePoints,
                strokeWidth: 4,
                color: const Color(0xFF3B82F6),
              ),
            ],
          ),

        MarkerLayer(
          markers: [
            _buildUserMarker(ctrl, night),
            ...ctrl.nearby.map(_buildNearbyMarker).toList(),
          ],
        ),
      ],
    );
  }

  Marker _buildUserMarker(ExploreController ctrl, bool night) {
    return Marker(
      point: ctrl.center,
      width: 42,
      height: 42,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: night ? Colors.black87 : Colors.white,
          border: Border.all(color: const Color(0xFF3B82F6), width: 3),
        ),
        child: const Icon(Icons.my_location, color: Color(0xFF3B82F6)),
      ),
    );
  }

  Marker _buildNearbyMarker(NearbyUser u) {
    final selected = widget.controller.selectedUser?.id == u.id;

    return Marker(
      point: LatLng(u.lat, u.lng),
      width: 52,
      height: 52,
      child: GestureDetector(
        onTap: () {
          widget.controller.setSelectedUser(u);
          setState(() => _showList = false);

          if (_mapReady) {
            _map.move(LatLng(u.lat, u.lng), 16.8);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? const Color(0xFFFF5A5F)
                : (widget.night ? Colors.black.withOpacity(0.7) : Colors.white),
            border: Border.all(
              color: const Color(0xFFFF5A5F),
              width: selected ? 3 : 2,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.location_on,
              color: selected ? Colors.white : const Color(0xFFFF5A5F),
              size: selected ? 32 : 28,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopControls(ExploreController ctrl, bool night) {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: night
                ? Colors.black.withOpacity(0.55)
                : Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.layers_outlined,
                  color: night ? Colors.white : Colors.black),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _showList ? "Lista" : "Mapa",
                  style: TextStyle(
                    color: night ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              PopupMenuButton<int>(
                onSelected: (i) => setState(() => _mapStyleIndex = i),
                itemBuilder: (_) => List.generate(
                  _mapStyles.length,
                  (i) => PopupMenuItem(
                    value: i,
                    child: Text(_mapStyles[i]['name']!),
                  ),
                ),
                child: Icon(Icons.palette_outlined,
                    color: night ? Colors.white : Colors.black),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => setState(() => _showList = !_showList),
                icon: Icon(
                  _showList ? Icons.map_outlined : Icons.list_alt_outlined,
                  color: night ? Colors.white : Colors.black,
                ),
              ),

              // ✅ REFRESH: ahora refresca cercanos + riesgo
              IconButton(
                icon: Icon(Icons.refresh_rounded,
                    color: night ? Colors.white : Colors.black),
                onPressed: () async {
                  await ctrl.loadNearby();
                  await ctrl.loadRiskZone();
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(String msg, bool night) {
    return Positioned(
      top: 72,
      left: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: night ? Colors.red.withOpacity(0.2) : Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: TextStyle(
                  color: night ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(ExploreController ctrl, bool night) {
    return Positioned(
      top: 132,
      left: 12,
      right: 12,
      bottom: 12,
      child: NearbyList(
        night: night,
        center: ctrl.center,
        users: ctrl.nearby,
        isLoading: ctrl.isLoadingNearby,
        errorText: ctrl.errorNearby,
        onSelect: (u) {
          widget.controller.setSelectedUser(u);
          setState(() => _showList = false);

          if (_mapReady) {
            _map.move(LatLng(u.lat, u.lng), 16.8);
          }
        },
      ),
    );
  }

  Widget _buildSelectedCard(ExploreController ctrl, bool night) {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: SelectedUserCard(
        night: night,
        user: ctrl.selectedUser!,
        center: ctrl.center,
        routeDistanceM: ctrl.routeDistanceM,
        routeDurationS: ctrl.routeDurationS,
        isLoadingRoute: ctrl.isLoadingRoute,
        canRoute: widget.incidentIdFromReport != null,
        onRoute: _loadRouteToIncident,
        onClearRoute: _clearRoute,
      ),
    );
  }
}
