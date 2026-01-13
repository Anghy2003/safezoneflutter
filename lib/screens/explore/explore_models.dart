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

/// =============================================================
/// MODELO: Incidente ligero para radar / mapa de riesgo
/// (Solo lo necesario para calcular zona peligrosa en el cliente)
/// =============================================================


class IncidenteLite {
  final int id;
  final String? tipo;
  final String? estado;
  final double? lat;
  final double? lng;
  final int? comunidadId;
  final String? comunidadNombre;
  final DateTime? fechaCreacion;
  final String? descripcion;

  IncidenteLite({
    required this.id,
    this.tipo,
    this.estado,
    this.lat,
    this.lng,
    this.comunidadId,
    this.comunidadNombre,
    this.fechaCreacion,
    this.descripcion,
  });

  factory IncidenteLite.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ??
        int.tryParse(json['id']?.toString() ?? '') ??
        0;

    final directLat = (json['lat'] as num?)?.toDouble();
    final directLng = (json['lng'] as num?)?.toDouble();

    final extracted = (directLat != null && directLng != null)
        ? _LatLng(directLat, directLng)
        : _extractLatLng(json);

    return IncidenteLite(
      id: id,
      tipo: json['tipo']?.toString(),
      estado: json['estado']?.toString(),
      lat: extracted?.lat,
      lng: extracted?.lng,
      comunidadId: (json['comunidadId'] as num?)?.toInt(),
      comunidadNombre: json['comunidadNombre']?.toString(),
      descripcion: json['descripcion']?.toString(),
      fechaCreacion: _parseDate(json['fechaCreacion']),
    );
  }

  LatLng? get point => (lat != null && lng != null) ? LatLng(lat!, lng!) : null;

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return null;
    }
  }

  static _LatLng? _extractLatLng(Map<String, dynamic> root) {
    final candidates = <dynamic>[
      root['ubicacion'],
      root['location'],
      root['point'],
      root['geom'],
      root['geometry'],
      root['ubicacionUsuario'],
    ];

    for (final c in candidates) {
      final got = _tryParseLatLng(c);
      if (got != null) return got;
    }

    // A veces viene anidado: incidente.ubicacion
    final inc = root['incidente'];
    final nested = _tryParseLatLng(inc is Map ? inc['ubicacion'] : null);
    if (nested != null) return nested;

    return null;
  }

  static _LatLng? _tryParseLatLng(dynamic v) {
    if (v == null) return null;

    // WKT: "POINT(lng lat)"
    if (v is String) {
      final s = v.trim();
      final m = RegExp(
        r'POINT\s*\(\s*([-\d.]+)\s+([-\d.]+)\s*\)',
        caseSensitive: false,
      ).firstMatch(s);
      if (m != null) {
        final lng = double.tryParse(m.group(1) ?? '');
        final lat = double.tryParse(m.group(2) ?? '');
        if (lat != null && lng != null) return _LatLng(lat, lng);
      }
      return null;
    }

    if (v is Map) {
      final map = Map<String, dynamic>.from(v);

      // {x:lng, y:lat}
      final x = map['x'];
      final y = map['y'];
      if (x is num && y is num) return _LatLng(y.toDouble(), x.toDouble());

      // {lat, lng}
      final lat = map['lat'];
      final lng = map['lng'];
      if (lat is num && lng is num) return _LatLng(lat.toDouble(), lng.toDouble());

      // GeoJSON: {type:"Point", coordinates:[lng,lat]}
      final coords = map['coordinates'];
      if (coords is List && coords.length >= 2) {
        final lng0 = coords[0];
        final lat0 = coords[1];
        if (lng0 is num && lat0 is num) return _LatLng(lat0.toDouble(), lng0.toDouble());
      }

      // {coordinates:{x,y}}
      final coordsObj = map['coordinates'];
      if (coordsObj is Map) {
        final xx = coordsObj['x'];
        final yy = coordsObj['y'];
        if (xx is num && yy is num) return _LatLng(yy.toDouble(), xx.toDouble());
      }

      // {coordinate:{x,y}}
      final coordinate = map['coordinate'];
      if (coordinate is Map) {
        final xx = coordinate['x'];
        final yy = coordinate['y'];
        if (xx is num && yy is num) return _LatLng(yy.toDouble(), xx.toDouble());
      }
    }

    return null;
  }
}

class _LatLng {
  final double lat;
  final double lng;
  _LatLng(this.lat, this.lng);
}
