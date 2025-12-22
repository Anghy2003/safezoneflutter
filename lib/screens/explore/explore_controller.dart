import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../service/auth_service.dart';
import 'explore_models.dart';

/// =============================================================
/// CONFIG GLOBAL API
/// =============================================================
class ApiConfig {
  static const String baseUrl = "http://192.168.3.25:8080/api";
}

/// =============================================================
/// MODELO SIMPLE PARA RESPUESTA DE /api/riesgo/zona
/// =============================================================
class ZonaRiesgoResponse {
  final String nivel; // BAJO | MEDIO | ALTO
  final double score; // 0..1
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
      radioM: (json['radioM'] ?? 0) as int,
      dias: (json['dias'] ?? 0) as int,
      total: (json['total'] ?? 0) as int,
      motivos: motivosJson
          .whereType<Map>()
          .map((e) => MotivoRiesgo.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class MotivoRiesgo {
  final String tipo;
  final int count;

  MotivoRiesgo({required this.tipo, required this.count});

  factory MotivoRiesgo.fromJson(Map<String, dynamic> json) {
    return MotivoRiesgo(
      tipo: (json['tipo'] ?? '').toString(),
      count: (json['count'] ?? 0) as int,
    );
  }
}

/// =============================================================
/// CONTROLADOR PRINCIPAL DEL RADAR + MAPA + RUTAS (+ RIESGO)
/// =============================================================
class ExploreController extends ChangeNotifier {
  ExploreController();

  // =============================================================
  // UBICACIÓN ACTUAL
  // =============================================================
  double currentLat = -2.9001;
  double currentLng = -79.0059;

  bool isLoadingLocation = false;

  // =============================================================
  // USUARIOS CERCANOS
  // =============================================================
  bool isLoadingNearby = false;
  String? errorNearby;
  List<NearbyUser> nearby = [];

  // FILTROS
  double radioMeters = 500;
  int lastMinutes = 20;
  int limit = 200;

  // =============================================================
  // RIESGO ZONA
  // =============================================================
  bool isLoadingRisk = false;
  String? errorRisk;
  ZonaRiesgoResponse? risk;

  // Config riesgo (independiente si quieres)
  int riskRadioM = 200;
  int riskDias = 30;

  // =============================================================
  // RUTA HACIA INCIDENTE
  // =============================================================
  bool isLoadingRoute = false;
  List<LatLng> routePoints = [];
  double? routeDistanceM;
  double? routeDurationS;
  String? errorRoute;

  // =============================================================
  // USUARIO SELECCIONADO
  // =============================================================
  NearbyUser? selectedUser;

  void setSelectedUser(NearbyUser? user) {
    selectedUser = user;
    notifyListeners();
  }

  // =============================================================
  // LatLng del usuario
  // =============================================================
  LatLng get center => LatLng(currentLat, currentLng);

  // =============================================================
  // MODO NOCHE
  // =============================================================
  bool get isNightMode {
    final hour = DateTime.now().hour;
    return hour >= 19 || hour < 7;
  }

  /// =============================================================
  /// Inicializa: reconstruye sesión + carga ubicación + usuarios cercanos + riesgo
  /// =============================================================
  Future<void> initialize() async {
    await AuthService.restoreSession();
    await loadLocation(); // loadLocation llama loadNearby() y loadRiskZone()
  }

  // =============================================================
  // UBICACIÓN DEL USUARIO (GPS)
  // =============================================================
  Future<void> loadLocation() async {
    errorNearby = null;
    isLoadingLocation = true;
    notifyListeners();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        errorNearby = "Activa el GPS para obtener tu ubicación exacta.";
        isLoadingLocation = false;
        notifyListeners();

        // Aun sin GPS, usamos ubicación por defecto:
        await loadNearby();
        await loadRiskZone();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        errorNearby =
            "Permiso de ubicación denegado. Se usará una ubicación por defecto.";
        isLoadingLocation = false;
        notifyListeners();

        await loadNearby();
        await loadRiskZone();
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        errorNearby = "Permiso denegado permanentemente. Activa en Ajustes.";
        isLoadingLocation = false;
        notifyListeners();

        await loadNearby();
        await loadRiskZone();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      currentLat = pos.latitude;
      currentLng = pos.longitude;
    } catch (e) {
      errorNearby = "Error obteniendo ubicación: $e";
    }

    isLoadingLocation = false;
    notifyListeners();

    await loadNearby();
    await loadRiskZone();
  }

  // =============================================================
  // CARGAR USUARIOS CERCANOS DESDE BACKEND
  // =============================================================
  Future<void> loadNearby() async {
    isLoadingNearby = true;
    errorNearby = null;
    notifyListeners();

    try {
      final uri = Uri.parse("${ApiConfig.baseUrl}/usuarios-cercanos").replace(
        queryParameters: {
          "lat": currentLat.toString(),
          "lng": currentLng.toString(),
          "radio": radioMeters.toString(),
          "lastMinutes": lastMinutes.toString(),
          "limit": limit.toString(),
        },
      );

      final resp = await http.get(uri, headers: AuthService.headers);

      if (resp.statusCode != 200) {
        errorNearby =
            "Error usuarios-cercanos (${resp.statusCode}): ${resp.body}";
        nearby = [];
      } else {
        final decoded = jsonDecode(resp.body);

        if (decoded is! List) {
          errorNearby = "Formato inesperado desde el backend";
          nearby = [];
        } else {
          nearby = decoded
              .whereType<Map>()
              .map((e) => NearbyUser.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }
    } catch (e) {
      errorNearby = "Error obteniendo usuarios cercanos: $e";
      nearby = [];
    }

    isLoadingNearby = false;
    notifyListeners();
  }

  // =============================================================
  // CARGAR RIESGO DE ZONA DESDE BACKEND
  // =============================================================
  Future<void> loadRiskZone() async {
    isLoadingRisk = true;
    errorRisk = null;
    notifyListeners();

    try {
      final uri = Uri.parse("${ApiConfig.baseUrl}/riesgo/zona").replace(
        queryParameters: {
          "lat": currentLat.toString(),
          "lng": currentLng.toString(),
          "radioM": riskRadioM.toString(),
          "dias": riskDias.toString(),
        },
      );

      final resp = await http.get(uri, headers: AuthService.headers);

      if (resp.statusCode != 200) {
        errorRisk = "Error riesgo (${resp.statusCode}): ${resp.body}";
        risk = null;
      } else {
        final decoded = jsonDecode(resp.body);
        if (decoded is! Map) {
          errorRisk = "Formato inesperado de riesgo";
          risk = null;
        } else {
          risk = ZonaRiesgoResponse.fromJson(Map<String, dynamic>.from(decoded));
        }
      }
    } catch (e) {
      errorRisk = "Error evaluando riesgo: $e";
      risk = null;
    }

    isLoadingRisk = false;
    notifyListeners();
  }

  // =============================================================
  // CARGAR RUTA HACIA INCIDENTE
  // =============================================================
  Future<void> loadRouteToIncident(String incidentId) async {
    isLoadingRoute = true;
    errorRoute = null;
    notifyListeners();

    try {
      final uri = Uri.parse("${ApiConfig.baseUrl}/incidentes/$incidentId/ruta")
          .replace(queryParameters: {
        "usuarioLat": currentLat.toString(),
        "usuarioLng": currentLng.toString(),
      });

      final resp = await http.get(uri, headers: AuthService.headers);

      if (resp.statusCode != 200) {
        errorRoute = "Error ruta (${resp.statusCode}): ${resp.body}";
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

  // =============================================================
  // LIMPIAR RUTA
  // =============================================================
  void clearRoute() {
    _clearRouteInternal();
    notifyListeners();
  }

  void _clearRouteInternal() {
    routePoints = [];
    routeDistanceM = null;
    routeDurationS = null;
  }
}
