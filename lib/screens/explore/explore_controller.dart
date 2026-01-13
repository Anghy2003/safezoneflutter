// lib/screens/explore/explore_controller.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../config/api_config.dart';
import '../../service/auth_service.dart';
import 'explore_models.dart';
import 'explore_offline_cache.dart';

// ============================
// MODELOS RIESGO
// ============================
class ZonaRiesgoResponse {
  final String nivel; // BAJO | MEDIO | ALTO
  final double score;
  final int radioM;
  final int dias;
  final int total;
  final List<MotivoRiesgo> motivos;

  ZonaRiesgoResponse({
    required this.nivel,
    required this.score,
    required this.radioM,
    required this.dias,
    required this.total,
    required this.motivos,
  });

  factory ZonaRiesgoResponse.fromJson(Map<String, dynamic> json) {
    final motivosJson = (json['motivos'] as List?) ?? [];
    return ZonaRiesgoResponse(
      nivel: (json['nivel'] ?? 'BAJO').toString(),
      score: (json['score'] ?? 0.0).toDouble(),
      radioM: (json['radioM'] ?? 0) is num ? (json['radioM'] as num).toInt() : 0,
      dias: (json['dias'] ?? 0) is num ? (json['dias'] as num).toInt() : 0,
      total: (json['total'] ?? 0) is num ? (json['total'] as num).toInt() : 0,
      motivos: motivosJson
          .whereType<Map>()
          .map((e) => MotivoRiesgo.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        "nivel": nivel,
        "score": score,
        "radioM": radioM,
        "dias": dias,
        "total": total,
        "motivos": motivos.map((m) => m.toJson()).toList(),
      };
}

class MotivoRiesgo {
  final String tipo;
  final int count;

  MotivoRiesgo({required this.tipo, required this.count});

  factory MotivoRiesgo.fromJson(Map<String, dynamic> json) {
    return MotivoRiesgo(
      tipo: (json['tipo'] ?? '').toString(),
      count: (json['count'] ?? 0) is num ? (json['count'] as num).toInt() : 0,
    );
  }

  Map<String, dynamic> toJson() => {"tipo": tipo, "count": count};
}

// ============================
// CONTROLLER
// ============================
class ExploreController extends ChangeNotifier {
  ExploreController();

  // ========== OFFLINE ==========
  bool isOffline = false;
  int? lastNearbyTs;
  int? lastRiskTs;
  int? lastIncidentsTs;

  int _lastOfflineWarnMillis = 0;

  // ========== UBICACIÓN ==========
  double currentLat = -2.9001;
  double currentLng = -79.0059;
  bool isLoadingLocation = false;

  // guardo precision de GPS (opcional, para enviar al backend)
  int? _lastPrecisionMeters;

  // ========== CERCANOS ==========
  bool isLoadingNearby = false;
  String? errorNearby;
  List<NearbyUser> nearby = [];

  double radioMeters = 500;
  int lastMinutes = 20;
  int limit = 200;

  // ========== RIESGO BACKEND ==========
  bool isLoadingRisk = false;
  String? errorRisk;
  ZonaRiesgoResponse? risk;

  int riskRadioM = 200;
  int riskDias = 30;

  // ========== INCIDENTES ==========
  bool isLoadingIncidents = false;
  String? errorIncidents;
  List<IncidenteLite> incidents = [];

  int dangerIncidentsInZone = 0;
  int dangerThreshold = 4;
  bool get isDangerousZone => dangerIncidentsInZone >= dangerThreshold;

  // ========== RUTA ==========
  bool isLoadingRoute = false;
  List<LatLng> routePoints = [];
  double? routeDistanceM;
  double? routeDurationS;
  String? errorRoute;

  // ========== SELECCIÓN ==========
  NearbyUser? selectedUser;
  IncidenteLite? selectedIncident;

  void setSelectedUser(NearbyUser? user) {
    selectedUser = user;
    notifyListeners();
  }

  void setSelectedIncident(IncidenteLite? inc) {
    selectedIncident = inc;
    notifyListeners();
  }

  LatLng get center => LatLng(currentLat, currentLng);

  bool get shouldWarnRiskOnRoute {
    if (routePoints.isEmpty) return false;
    final nivel = (risk?.nivel ?? '').toUpperCase();
    return nivel == 'MEDIO' || nivel == 'ALTO';
  }

  String? get photoUrl => null;

  String? get displayName => null;

  // ==========================================
  // INTERNET REAL
  // ==========================================
  Future<bool> _hasInternet() async {
    try {
      final r = await InternetAddress.lookup('example.com')
          .timeout(const Duration(seconds: 2));
      return r.isNotEmpty && r.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _setOfflineBannerOnce(String _) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastOfflineWarnMillis < 6000) return;
    _lastOfflineWarnMillis = now;
  }

  // ==========================================
  // BASE URL HELPERS (evita /api/api)
  // ==========================================
  String _normBase(String base) {
    final b = base.trim();
    if (b.endsWith('/')) return b.substring(0, b.length - 1);
    return b;
  }

  String _api(String path) {
    // path debe venir con "/" al inicio
    final b = _normBase(ApiConfig.baseUrl);

    // Si base ya termina en "/api", no duplicamos.
    if (b.endsWith('/api')) return '$b$path';

    // Si NO termina en /api, lo agregamos.
    return '$b/api$path';
  }

  String _plain(String path) {
    // para endpoints que NO están bajo /api (ej: /incidentes, /riesgo/zona, etc.)
    final b = _normBase(ApiConfig.baseUrl);
    return '$b$path';
  }

  // ==========================================
  // INIT
  // ==========================================
  Future<void> initialize() async {
    try {
      await AuthService.restoreSession();
    } catch (_) {}

    await _loadCachedState();
    await loadLocation(); // esto llama nearby+risk
    await loadIncidents();
  }

  Future<void> _loadCachedState() async {
    try {
      final loc = await ExploreOfflineCache.loadLastLocation();
      if (loc != null) {
        currentLat = (loc["lat"] as num?)?.toDouble() ?? currentLat;
        currentLng = (loc["lng"] as num?)?.toDouble() ?? currentLng;
      }

      final cachedNearby = await ExploreOfflineCache.loadNearby();
      if (cachedNearby.isNotEmpty) {
        nearby = cachedNearby.map((e) => NearbyUser.fromJson(e)).toList();
      }
      lastNearbyTs = await ExploreOfflineCache.loadNearbyTs();

      final cachedRisk = await ExploreOfflineCache.loadRisk();
      if (cachedRisk != null) {
        risk = ZonaRiesgoResponse.fromJson(cachedRisk);
      }
      lastRiskTs = await ExploreOfflineCache.loadRiskTs();

      final cachedInc = await ExploreOfflineCache.loadIncidents();
      if (cachedInc.isNotEmpty) {
        incidents = cachedInc.map((e) => IncidenteLite.fromJson(e)).toList();
        _evaluateDangerZone();
      }
      lastIncidentsTs = await ExploreOfflineCache.loadIncidentsTs();

      notifyListeners();
    } catch (_) {}
  }

  // ==========================================
  // UBICACIÓN (GPS local)
  // ==========================================
  Future<void> loadLocation() async {
    errorNearby = null;
    isLoadingLocation = true;
    notifyListeners();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          errorNearby =
              "Permiso de ubicación denegado. Usando última ubicación guardada.";
        } else {
          Position? pos;
          try {
            pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            ).timeout(const Duration(seconds: 6));
          } catch (_) {
            pos = await Geolocator.getLastKnownPosition();
          }

          if (pos != null) {
            currentLat = pos.latitude;
            currentLng = pos.longitude;
            _lastPrecisionMeters = (pos.accuracy.isFinite)
                ? pos.accuracy.round()
                : null;

            await ExploreOfflineCache.saveLastLocation(
              lat: currentLat,
              lng: currentLng,
              tsMillis: DateTime.now().millisecondsSinceEpoch,
            );
          }
        }
      } else {
        errorNearby = "GPS apagado. Usando última ubicación guardada.";
      }
    } catch (e) {
      errorNearby = "Error obteniendo ubicación: $e";
    }

    isLoadingLocation = false;
    notifyListeners();

    // Con ubicación actualizada, refrescamos datos
    await loadNearby(); // incluye POST ubicacion/actual + GET cercanos
    await loadRiskZone();

    _evaluateDangerZone();
    notifyListeners();
  }

  // ==========================================
  // UBICACIÓN -> BACKEND (POST /api/ubicaciones-usuario/actual)
  // ==========================================
  Future<int?> _resolveUsuarioId() async {
    // ✅ Este es tu id guardado en SharedPreferences.
    // Además rehidrata _legacyUserId internamente (para X-User-Id en headers).
    return await AuthService.getCurrentUserId();
  }

  Future<void> _pushMyLocationToBackend({int? precisionMeters}) async {
    final int? userId = await _resolveUsuarioId();
    if (userId == null || userId <= 0) return;

    final uri = Uri.parse(_api("/ubicaciones-usuario/actual")).replace(
      queryParameters: {
        "usuarioId": userId.toString(),
        "lat": currentLat.toString(),
        "lng": currentLng.toString(),
        if (precisionMeters != null) "precision": precisionMeters.toString(),
      },
    );

    final resp = await http
        .post(uri, headers: AuthService.headers)
        .timeout(const Duration(seconds: 10));

    // si falla, no rompemos el flujo
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      // opcional: debugPrint("push location failed ${resp.statusCode} ${resp.body}");
    }
  }

  // ==========================================
  // CERCANOS (POST ubicacion/actual + GET /api/usuarios-cercanos)
  // ==========================================
  Future<void> loadNearby() async {
    isLoadingNearby = true;
    errorNearby = null;
    notifyListeners();

    final online = await _hasInternet();
    if (!online) {
      isOffline = true;
      _setOfflineBannerOnce("offline_nearby");
      errorNearby = "Sin internet: mostrando cercanos guardados.";
      try {
        final cached = await ExploreOfflineCache.loadNearby();
        nearby = cached.map((e) => NearbyUser.fromJson(e)).toList();
        lastNearbyTs = await ExploreOfflineCache.loadNearbyTs();
      } catch (_) {
        nearby = [];
      }
      isLoadingNearby = false;
      notifyListeners();
      return;
    }

    isOffline = false;

    try {
      // 1) Subir mi ubicación
      await _pushMyLocationToBackend(precisionMeters: _lastPrecisionMeters);

      // 2) Consultar cercanos
      final uri = Uri.parse(_api("/usuarios-cercanos")).replace(
        queryParameters: {
          "lat": currentLat.toString(),
          "lng": currentLng.toString(),
          "radio": radioMeters.toString(),
          "lastMinutes": lastMinutes.toString(),
          "limit": limit.toString(),
        },
      );

      final resp = await http
          .get(uri, headers: AuthService.headers)
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) {
        errorNearby = "Error usuarios-cercanos (${resp.statusCode})";
        final cached = await ExploreOfflineCache.loadNearby();
        nearby = cached.map((e) => NearbyUser.fromJson(e)).toList();
      } else {
        final decoded = jsonDecode(resp.body);
        if (decoded is! List) {
          errorNearby = "Formato inesperado desde el backend";
          final cached = await ExploreOfflineCache.loadNearby();
          nearby = cached.map((e) => NearbyUser.fromJson(e)).toList();
        } else {
          final list = decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

          nearby = list.map((e) => NearbyUser.fromJson(e)).toList();
          await ExploreOfflineCache.saveNearby(list);
          lastNearbyTs = await ExploreOfflineCache.loadNearbyTs();
        }
      }
    } catch (e) {
      errorNearby = "Error obteniendo usuarios cercanos: $e";
      final cached = await ExploreOfflineCache.loadNearby();
      nearby = cached.map((e) => NearbyUser.fromJson(e)).toList();
    }

    isLoadingNearby = false;
    notifyListeners();
  }

  // ==========================================
  // RIESGO (GET /riesgo/zona)  -> aquí NO usas /api en tu código original
  // ==========================================
  Future<void> loadRiskZone() async {
    isLoadingRisk = true;
    errorRisk = null;
    notifyListeners();

    final online = await _hasInternet();
    if (!online) {
      isOffline = true;
      _setOfflineBannerOnce("offline_risk");
      errorRisk = "Sin internet: mostrando riesgo guardado.";
      final cached = await ExploreOfflineCache.loadRisk();
      risk = cached != null ? ZonaRiesgoResponse.fromJson(cached) : risk;
      lastRiskTs = await ExploreOfflineCache.loadRiskTs();
      isLoadingRisk = false;
      notifyListeners();
      return;
    }

    isOffline = false;

    try {
      final uri = Uri.parse(_plain("/riesgo/zona")).replace(
        queryParameters: {
          "lat": currentLat.toString(),
          "lng": currentLng.toString(),
          "radioM": riskRadioM.toString(),
          "dias": riskDias.toString(),
        },
      );

      final resp = await http
          .get(uri, headers: AuthService.headers)
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) {
        errorRisk = "Error riesgo (${resp.statusCode})";
        final cached = await ExploreOfflineCache.loadRisk();
        risk = cached != null ? ZonaRiesgoResponse.fromJson(cached) : null;
      } else {
        final decoded = jsonDecode(resp.body);
        if (decoded is! Map) {
          errorRisk = "Formato inesperado de riesgo";
          final cached = await ExploreOfflineCache.loadRisk();
          risk = cached != null ? ZonaRiesgoResponse.fromJson(cached) : null;
        } else {
          final map = Map<String, dynamic>.from(decoded);
          risk = ZonaRiesgoResponse.fromJson(map);
          await ExploreOfflineCache.saveRisk(map);
          lastRiskTs = await ExploreOfflineCache.loadRiskTs();
        }
      }
    } catch (e) {
      errorRisk = "Error evaluando riesgo: $e";
      final cached = await ExploreOfflineCache.loadRisk();
      risk = cached != null ? ZonaRiesgoResponse.fromJson(cached) : null;
    }

    isLoadingRisk = false;
    notifyListeners();
  }

  // ==========================================
  // INCIDENTES (GET /incidentes)
  // ==========================================
  Future<void> loadIncidents() async {
    isLoadingIncidents = true;
    errorIncidents = null;
    notifyListeners();

    final online = await _hasInternet();
    if (!online) {
      isOffline = true;
      _setOfflineBannerOnce("offline_incidents");
      errorIncidents = "Sin internet: mostrando incidentes guardados.";
      final cached = await ExploreOfflineCache.loadIncidents();
      incidents = cached.map((e) => IncidenteLite.fromJson(e)).toList();
      lastIncidentsTs = await ExploreOfflineCache.loadIncidentsTs();
      _evaluateDangerZone();
      isLoadingIncidents = false;
      notifyListeners();
      return;
    }

    isOffline = false;

    try {
      final uri = Uri.parse(_plain("/incidentes"));

      final resp = await http
          .get(uri, headers: AuthService.headers)
          .timeout(const Duration(seconds: 12));

      if (resp.statusCode != 200) {
        errorIncidents = "Error incidentes (${resp.statusCode})";
        final cached = await ExploreOfflineCache.loadIncidents();
        incidents = cached.map((e) => IncidenteLite.fromJson(e)).toList();
      } else {
        final decoded = jsonDecode(resp.body);
        if (decoded is! List) {
          errorIncidents = "Formato inesperado de incidentes";
          final cached = await ExploreOfflineCache.loadIncidents();
          incidents = cached.map((e) => IncidenteLite.fromJson(e)).toList();
        } else {
          final list = decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

          incidents = list.map((e) => IncidenteLite.fromJson(e)).toList();
          await ExploreOfflineCache.saveIncidents(list);
          lastIncidentsTs = await ExploreOfflineCache.loadIncidentsTs();
        }
      }
    } catch (e) {
      errorIncidents = "Error cargando incidentes: $e";
      final cached = await ExploreOfflineCache.loadIncidents();
      incidents = cached.map((e) => IncidenteLite.fromJson(e)).toList();
    }

    _evaluateDangerZone();
    isLoadingIncidents = false;
    notifyListeners();
  }

  void _evaluateDangerZone() {
    if (incidents.isEmpty) {
      dangerIncidentsInZone = 0;
      return;
    }

    final distance = const Distance();
    final now = DateTime.now();
    final maxAge = Duration(days: riskDias);
    final centerPoint = LatLng(currentLat, currentLng);

    int count = 0;

    for (final inc in incidents) {
      if (inc.point == null) continue;
      if (inc.fechaCreacion == null) continue;

      final diff = now.difference(inc.fechaCreacion!);
      if (diff.isNegative || diff > maxAge) continue;

      final d = distance.as(LengthUnit.Meter, centerPoint, inc.point!);
      if (d <= riskRadioM) count++;
    }

    dangerIncidentsInZone = count;
  }

  void updateRiskConfig({int? radioM, int? dias}) {
    if (radioM != null) riskRadioM = radioM;
    if (dias != null) riskDias = dias;
    _evaluateDangerZone();
    notifyListeners();
  }

  // ==========================================
  // RUTA (GET /incidentes/{id}/ruta)
  // ==========================================
  Future<void> loadRouteToIncident(String incidentId) async {
    isLoadingRoute = true;
    errorRoute = null;
    notifyListeners();

    final online = await _hasInternet();
    if (!online) {
      isOffline = true;
      _setOfflineBannerOnce("offline_route");
      errorRoute = "Sin internet: no se puede calcular ruta.";
      _clearRouteInternal();
      isLoadingRoute = false;
      notifyListeners();
      return;
    }

    isOffline = false;

    try {
      final uri = Uri.parse(_plain("/incidentes/$incidentId/ruta")).replace(
        queryParameters: {
          "usuarioLat": currentLat.toString(),
          "usuarioLng": currentLng.toString(),
        },
      );

      final resp = await http
          .get(uri, headers: AuthService.headers)
          .timeout(const Duration(seconds: 12));

      if (resp.statusCode != 200) {
        errorRoute = "Error ruta (${resp.statusCode})";
        _clearRouteInternal();
        return;
      }

      final decoded = jsonDecode(resp.body);
      if (decoded is! Map) {
        errorRoute = "Formato de ruta inesperado";
        _clearRouteInternal();
        return;
      }

      final route = RouteResponse.fromJson(Map<String, dynamic>.from(decoded));
      if (!route.ok || route.points.isEmpty) {
        errorRoute = "No se pudo calcular la ruta.";
        _clearRouteInternal();
        return;
      }

      routePoints = route.points;
      routeDistanceM = route.distanceMeters;
      routeDurationS = route.durationSeconds;
    } catch (e) {
      errorRoute = "Error calculando ruta: $e";
      _clearRouteInternal();
    } finally {
      isLoadingRoute = false;
      notifyListeners();
    }
  }

  void clearRoute() {
    _clearRouteInternal();
    notifyListeners();
  }

  void _clearRouteInternal() {
    routePoints = [];
    routeDistanceM = null;
    routeDurationS = null;
  }

  // ==========================================
  // Helpers UI: iconos/colores por tipo
  // ==========================================
  String normalizeIncidentType(String? tipo) {
    final t = (tipo ?? '').trim().toUpperCase();
    if (t.isEmpty) return 'INCIDENTE';
    return t;
  }

  IconData incidentIconFor(String? tipo) {
    final t = normalizeIncidentType(tipo);

    if (t.contains('VIOLEN')) return Icons.report_gmailerrorred_rounded;
    if (t.contains('ROBO')) return Icons.local_police_rounded;
    if (t.contains('FUEGO') || t.contains('INCEND')) {
      return Icons.local_fire_department_rounded;
    }
    if (t.contains('SALUD') || t.contains('MED')) {
      return Icons.medical_services_rounded;
    }
    if (t.contains('ACCIDENT')) return Icons.car_crash_rounded;

    if (t.startsWith('SOS_')) return Icons.sos_rounded;

    return Icons.warning_amber_rounded;
  }

  Color incidentColorFor(String? tipo) {
    final t = normalizeIncidentType(tipo);

    if (t.contains('VIOLEN')) return const Color(0xFFE11D48);
    if (t.contains('ROBO')) return const Color(0xFF7C3AED);
    if (t.contains('FUEGO') || t.contains('INCEND')) {
      return const Color(0xFFF97316);
    }
    if (t.contains('SALUD') || t.contains('MED')) {
      return const Color(0xFF10B981);
    }
    if (t.contains('ACCIDENT')) return const Color(0xFF3B82F6);
    if (t.startsWith('SOS_')) return const Color(0xFFFF5A5F);

    return const Color(0xFFF59E0B);
  }

  // ==========================================
  // Refresco total
  // ==========================================
  Future<void> refreshAll() async {
    await loadLocation(); // ya llama nearby+risk
    await loadIncidents();
  }
}
