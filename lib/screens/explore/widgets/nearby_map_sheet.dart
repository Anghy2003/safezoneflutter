import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';

import 'package:safezone_app/screens/explore/widgets/selected_incident_card.dart';
import 'package:safezone_app/screens/explore/widgets/selected_user_card.dart';

import '../explore_controller.dart';
import '../explore_models.dart';

import 'nearby_list.dart';
import 'incident_pin.dart';
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

class _NearbyMapSheetState extends State<NearbyMapSheet>
    with SingleTickerProviderStateMixin {
  late final MapController _map;
  bool _mapReady = false;

  bool _showList = false;
  int _mapStyleIndex = 0;
  bool _autoRouteRequested = false;

  // ✅ Radar animado
  late final AnimationController _radar;

  static const String _storeName = 'safezone_tiles';
  static const Color _routeColor = Color(0xFFF95150);

  final List<Map<String, String>> _mapStyles = const [
    {'name': 'Clásico', 'url': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'},
    {
      'name': 'Humanitario',
      'url': 'https://tile-a.openstreetmap.fr/hot/{z}/{x}/{y}.png'
    },
    {
      'name': 'Oscuro',
      'url':
          'https://cartodb-basemaps-a.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png'
    },
  ];

  @override
  void initState() {
    super.initState();
    _map = MapController();

    _radar = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _radar.dispose();
    _map.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Auto-ruta si vienes desde reporte con id
    final id = widget.incidentIdFromReport;
    if (!_autoRouteRequested && id != null && id.isNotEmpty) {
      _autoRouteRequested = true;
      _loadRouteToIncident(id);
    }
  }

  Future<void> _loadRouteToIncident(String incidentId) async {
    await widget.controller.loadRouteToIncident(incidentId);

    final pts = widget.controller.routePoints;
    if (_mapReady && pts.isNotEmpty) {
      _map.move(pts.first, 17.0);
    }
    if (mounted) setState(() {});
  }

  void _clearRoute() {
    widget.controller.clearRoute();
    if (mounted) setState(() {});
  }

  // =========================
  // CLUSTER: centro robusto
  // (NO usa cluster.point ni cluster.location)
  // =========================
  LatLng _clusterCenterFromMarkers(List<Marker> markers) {
    if (markers.isEmpty) return widget.controller.center;

    double lat = 0;
    double lng = 0;
    int n = 0;

    for (final m in markers) {
      lat += m.point.latitude;
      lng += m.point.longitude;
      n++;
    }

    return LatLng(lat / n, lng / n);
  }

  void _zoomInOn(LatLng p) {
    if (!_mapReady) return;
    final z = _map.camera.zoom;
    final targetZoom = (z < 18.0) ? (z + 1.3).clamp(16.0, 18.5) : 18.5;
    _map.move(p, targetZoom);
  }

  // “Inteligente”: ajusta radio de cluster según zoom y densidad
  int _clusterRadiusFor({required int count, required double zoom}) {
    // a mayor zoom → cluster más pequeño (se “abre”)
    if (zoom >= 17.5) return 45;
    if (zoom >= 16.5) return 55;
    if (zoom >= 15.5) return 65;

    // si está lejos y hay muchos, agrupa más fuerte
    if (count >= 80) return 95;
    if (count >= 40) return 85;
    return 75;
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
            RiskBadge(
              night: night,
              isLoading: ctrl.isLoadingRisk,
              nivel: ctrl.risk?.nivel,
              total: ctrl.risk?.total,
            ),
            const SizedBox(width: 10),
            Text(
              ctrl.isLoadingNearby ? "Buscando..." : "Usuarios: ${ctrl.nearby.length}",
              style: TextStyle(
                color: night ? Colors.white70 : Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
            if (ctrl.isOffline)
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
          ],
        ),
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
              if (ctrl.isDangerousZone) _buildDangerZoneBanner(ctrl, night),

              if (_showList) _buildList(ctrl, night),

              if (ctrl.selectedIncident != null && !_showList)
                _buildSelectedIncidentCard(ctrl, night),

              if (ctrl.selectedUser != null && !_showList)
                _buildSelectedUserCard(ctrl, night),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMap(ExploreController ctrl, bool night) {
    final loadingStrategy = ctrl.isOffline
        ? BrowseLoadingStrategy.cacheOnly
        : BrowseLoadingStrategy.onlineFirst;

    final tileProvider = FMTCTileProvider(
      stores: {_storeName: BrowseStoreStrategy.readUpdateCreate},
      loadingStrategy: loadingStrategy,
    );

    // ✅ Construimos markers (no layers) para cluster
    final nearbyMarkers = ctrl.nearby.map((u) => _nearbyMarker(u, night)).toList();
    final incidentMarkers = _incidentMarkersAsMarkers(ctrl, night);

    // ✅ Cluster inteligente: usa zoom actual si existe
    final currentZoom = _mapReady ? _map.camera.zoom : 16.0;

    final userClusterRadius = _clusterRadiusFor(
      count: nearbyMarkers.length,
      zoom: currentZoom,
    );
    final incClusterRadius = _clusterRadiusFor(
      count: incidentMarkers.length,
      zoom: currentZoom,
    );

    return AnimatedBuilder(
      animation: _radar,
      builder: (_, __) {
        final t = _radar.value; // 0..1
        return FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: ctrl.center,
            initialZoom: 16,
            onMapReady: () {
              _mapReady = true;
              setState(() => _map.move(ctrl.center, 16));
            },
            onTap: (_, __) {
              // cerrar selección tocando mapa
              ctrl.setSelectedUser(null);
              ctrl.setSelectedIncident(null);
              if (mounted) setState(() {});
            },
          ),
          children: [
            TileLayer(
              urlTemplate: _mapStyles[_mapStyleIndex]['url']!,
              userAgentPackageName: "com.safezone.app",
              tileProvider: tileProvider,
            ),

            // =========================
            // ✅ RADAR ANIMADO (3 pulsos)
            // =========================
            CircleLayer(
              circles: _radarCircles(ctrl, night, t),
            ),

            // Zona peligrosa (fijo)
            if (ctrl.isDangerousZone)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: ctrl.center,
                    radius: ctrl.riskRadioM.toDouble(),
                    useRadiusInMeter: true,
                    color: Colors.red.withOpacity(0.28),
                    borderColor: Colors.redAccent.withOpacity(0.85),
                    borderStrokeWidth: 3,
                  ),
                ],
              ),

            // Ruta
            if (ctrl.routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: ctrl.routePoints,
                    strokeWidth: 5,
                    color: _routeColor,
                  ),
                ],
              ),

            // Mi marcador (no cluster)
            MarkerLayer(
              markers: [
                _buildUserMarker(ctrl, night),
              ],
            ),

            // =========================
            // ✅ CLUSTER: USUARIOS
            // =========================
            if (nearbyMarkers.isNotEmpty)
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  markers: nearbyMarkers,
                  maxClusterRadius: userClusterRadius,
                  size: const Size(52, 52),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(50),

                  // tap en cluster → zoom hacia el centro
                  onClusterTap: (cluster) {
                    // NO usamos cluster.point/location para evitar errores.
                    final m = (cluster as dynamic).markers;
                    if (m is List<Marker>) {
                      _zoomInOn(_clusterCenterFromMarkers(m));
                    }
                  },

                  builder: (context, markers) => _clusterBubble(
                    night: night,
                    count: markers.length,
                    accent: const Color(0xFF3B82F6),
                    icon: Icons.group_rounded,
                  ),

                  // spiderfy (evita solaparse)
                  spiderfyCircleRadius: 80,
                  spiderfySpiralDistanceMultiplier: 2, // ✅ int (no double)
                ),
              ),

            // =========================
            // ✅ CLUSTER: INCIDENTES
            // =========================
            if (incidentMarkers.isNotEmpty)
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  markers: incidentMarkers,
                  maxClusterRadius: incClusterRadius,
                  size: const Size(52, 52),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(50),
                  onClusterTap: (cluster) {
                    final m = (cluster as dynamic).markers;
                    if (m is List<Marker>) {
                      _zoomInOn(_clusterCenterFromMarkers(m));
                    }
                  },
                  builder: (context, markers) => _clusterBubble(
                    night: night,
                    count: markers.length,
                    accent: const Color(0xFFF59E0B),
                    icon: Icons.warning_amber_rounded,
                  ),
                  spiderfyCircleRadius: 90,
                  spiderfySpiralDistanceMultiplier: 2, // ✅ int
                ),
              ),
          ],
        );
      },
    );
  }

  // =========================
  // RADAR circles
  // =========================
  List<CircleMarker> _radarCircles(ExploreController ctrl, bool night, double t) {
    // t: 0..1
    final base = ctrl.radioMeters.toDouble();

    // 3 ondas
    final r1 = base * (0.35 + 0.65 * t);
    final r2 = base * (0.20 + 0.80 * ((t + 0.33) % 1.0));
    final r3 = base * (0.10 + 0.90 * ((t + 0.66) % 1.0));

    double o(double x) => (1.0 - x).clamp(0.0, 1.0);

    final c = const Color(0xFFFF5A5F);
    final fill = night ? 0.12 : 0.10;

    return [
      CircleMarker(
        point: ctrl.center,
        radius: r1,
        useRadiusInMeter: true,
        color: c.withOpacity(fill * o(t)),
        borderColor: c.withOpacity(0.55 * o(t)),
        borderStrokeWidth: 2,
      ),
      CircleMarker(
        point: ctrl.center,
        radius: r2,
        useRadiusInMeter: true,
        color: c.withOpacity((fill * 0.75) * o((t + 0.33) % 1.0)),
        borderColor: c.withOpacity((0.50) * o((t + 0.33) % 1.0)),
        borderStrokeWidth: 2,
      ),
      CircleMarker(
        point: ctrl.center,
        radius: r3,
        useRadiusInMeter: true,
        color: c.withOpacity((fill * 0.55) * o((t + 0.66) % 1.0)),
        borderColor: c.withOpacity((0.45) * o((t + 0.66) % 1.0)),
        borderStrokeWidth: 2,
      ),
    ];
  }

  // =========================
  // MARKERS: mi usuario
  // =========================
  Marker _buildUserMarker(ExploreController ctrl, bool night) {
    return Marker(
      point: ctrl.center,
      width: 44,
      height: 44,
      child: GestureDetector(
        onTap: () {
          ctrl.setSelectedUser(null);
          ctrl.setSelectedIncident(null);
          if (mounted) setState(() {});
        },
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: night ? Colors.black87 : Colors.white,
            border: Border.all(color: const Color(0xFF3B82F6), width: 3),
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                spreadRadius: 1,
                color: Colors.black.withOpacity(0.18),
              ),
            ],
          ),
          child: const Icon(Icons.my_location, color: Color(0xFF3B82F6)),
        ),
      ),
    );
  }

  // =========================
  // MARKER: usuario cercano
  // =========================
  Marker _nearbyMarker(NearbyUser u, bool night) {
    final ctrl = widget.controller;
    final selected = ctrl.selectedUser?.id == u.id;
    final avatarUrl = (u.avatarUrl ?? '').trim();

    return Marker(
      point: LatLng(u.lat, u.lng),
      width: selected ? 58 : 52,
      height: selected ? 58 : 52,
      child: GestureDetector(
        onTap: () {
          ctrl.setSelectedUser(u);
          ctrl.setSelectedIncident(null);
          ctrl.clearRoute();

          setState(() => _showList = false);
          if (_mapReady) _map.move(LatLng(u.lat, u.lng), 16.8);
        },
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? const Color(0xFFFF5A5F) : Colors.white,
            border: Border.all(
              color: const Color(0xFFFF5A5F),
              width: selected ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                spreadRadius: 1,
                color: Colors.black.withOpacity(0.18),
              ),
            ],
          ),
          padding: const EdgeInsets.all(3),
          child: ClipOval(
            child: avatarUrl.isNotEmpty
                ? Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallbackAvatar(u),
                  )
                : _fallbackAvatar(u),
          ),
        ),
      ),
    );
  }

  Widget _fallbackAvatar(NearbyUser u) {
    final initial = u.name.trim().isNotEmpty ? u.name.trim()[0].toUpperCase() : 'U';
    return Container(
      color: const Color(0xFF111827),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  // =========================
  // MARKERS: incidentes como Marker
  // =========================
  List<Marker> _incidentMarkersAsMarkers(ExploreController ctrl, bool night) {
    final list = <Marker>[];

    for (final inc in ctrl.incidents) {
      final p = inc.point;
      if (p == null) continue;

      final selected = ctrl.selectedIncident?.id == inc.id;

      list.add(
        Marker(
          point: p,
          width: 210,
          height: 90,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () async {
              ctrl.setSelectedIncident(inc);
              ctrl.setSelectedUser(null);

              ctrl.clearRoute();
              setState(() => _showList = false);

              if (_mapReady) _map.move(p, 17.0);

              final id = inc.id.toString();
              if (id.isNotEmpty) {
                await ctrl.loadRouteToIncident(id);
              }

              if (mounted) setState(() {});
            },
            child: IncidentPin(
              inc: inc,
              night: night,
              selected: selected,
            ),
          ),
        ),
      );
    }

    return list;
  }

  // =========================
  // UI: Bubble de cluster
  // =========================
  Widget _clusterBubble({
    required bool night,
    required int count,
    required Color accent,
    required IconData icon,
  }) {
    final double size = 44 + (math.min(count, 60) / 60) * 18; // 44..62 aprox
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: night ? Colors.black.withOpacity(0.65) : Colors.white.withOpacity(0.95),
        border: Border.all(color: accent.withOpacity(0.95), width: 2.2),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            spreadRadius: 1,
            color: Colors.black.withOpacity(night ? 0.40 : 0.18),
          ),
        ],
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 6),
            Text(
              "$count",
              style: TextStyle(
                color: night ? Colors.white : Colors.black,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // TOP controls
  // =========================
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
                  (i) => PopupMenuItem(value: i, child: Text(_mapStyles[i]['name']!)),
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
              IconButton(
                icon: Icon(Icons.refresh_rounded,
                    color: night ? Colors.white : Colors.black),
                onPressed: () async {
                  await ctrl.loadNearby();
                  await ctrl.loadRiskZone();
                  await ctrl.loadIncidents();
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDangerZoneBanner(ExploreController ctrl, bool night) {
    return Positioned(
      bottom: 110,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(night ? 0.38 : 0.25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent.withOpacity(0.8), width: 1.6),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Zona peligrosa: ${ctrl.dangerIncidentsInZone} incidentes "
                "en los últimos ${ctrl.riskDias} días dentro de ${ctrl.riskRadioM} m.",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
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
          ctrl.setSelectedUser(u);
          ctrl.setSelectedIncident(null);
          ctrl.clearRoute();

          setState(() => _showList = false);

          if (_mapReady) {
            _map.move(LatLng(u.lat, u.lng), 16.8);
          }
        },
      ),
    );
  }

  Widget _buildSelectedIncidentCard(ExploreController ctrl, bool night) {
    return Positioned(
      left: 12,
      right: 12,
      bottom: (ctrl.selectedUser != null) ? 86 : 12,
      child: SelectedIncidentCard(
        night: night,
        inc: ctrl.selectedIncident!,
        isLoadingRoute: ctrl.isLoadingRoute,
        routeDistanceM: ctrl.routeDistanceM,
        routeDurationS: ctrl.routeDurationS,
        onRoute: () async {
          final id = ctrl.selectedIncident?.id.toString();
          if (id == null || id.isEmpty) return;

          ctrl.clearRoute();
          await ctrl.loadRouteToIncident(id);

          if (_mapReady && ctrl.routePoints.isNotEmpty) {
            _map.move(ctrl.routePoints.first, 17.0);
          }
          if (mounted) setState(() {});
        },
        onClear: _clearRoute,
        onClose: () {
          ctrl.setSelectedIncident(null);
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Widget _buildSelectedUserCard(ExploreController ctrl, bool night) {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: SelectedUserCard(
        night: night,
        user: ctrl.selectedUser!,
        center: ctrl.center,

        // ✅ No ruta a usuario
        routeDistanceM: null,
        routeDurationS: null,
        isLoadingRoute: false,

        canRoute: false,
        onRoute: null,

        onClearRoute: _clearRoute,
        onCenter: () {
          if (_mapReady) _map.move(LatLng(ctrl.selectedUser!.lat, ctrl.selectedUser!.lng), 16.8);
        },
      ),
    );
  }
}
