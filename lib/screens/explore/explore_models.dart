import 'package:latlong2/latlong.dart';

/// =============================================================
/// MODELO: Usuario Cercano
/// =============================================================
class NearbyUser {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String? avatarUrl;

  NearbyUser({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.avatarUrl,
  });

  factory NearbyUser.fromJson(Map<String, dynamic> json) {
    return NearbyUser(
      id: json['id'].toString(),
      name: (json['name'] ?? 'Usuario').toString(),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      avatarUrl: json['avatarUrl']?.toString(),
    );
  }
}

/// =============================================================
/// MODELO: Respuesta de Ruta desde Backend
/// Se espera: { ok, distanceMeters, durationSeconds, coordinates: [[lng,lat],...] }
/// =============================================================
class RouteResponse {
  final bool ok;
  final double distanceMeters;
  final double durationSeconds;
  final List<LatLng> points;

  RouteResponse({
    required this.ok,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.points,
  });

  factory RouteResponse.fromJson(Map<String, dynamic> json) {
    final coords = (json['coordinates'] as List? ?? []);

    final pts = coords.map<LatLng>((p) {
      final lng = (p[0] as num).toDouble();
      final lat = (p[1] as num).toDouble();
      return LatLng(lat, lng);
    }).toList();

    return RouteResponse(
      ok: json['ok'] == true,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
      durationSeconds: (json['durationSeconds'] as num?)?.toDouble() ?? 0,
      points: pts,
    );
  }
}
