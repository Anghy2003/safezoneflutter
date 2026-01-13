// lib/services/incidente_stats_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../service/auth_service.dart';

class IncidenteStats {
  final int total; // total histórico (todos los reportes del usuario)
  final List<int> last7Days; // 7 días (oldest -> today)

  const IncidenteStats({
    required this.total,
    required this.last7Days,
  });
}

class IncidenteStatsService {
  static String get baseUrl => ApiConfig.baseUrl;

  // ---------------------------------------------------------
  // PUBLIC API
  // ---------------------------------------------------------
  static Future<IncidenteStats> fetchMyStats7Days() async {
    final userId = await AuthService.getCurrentUserId();
    if (userId == null) {
      return const IncidenteStats(total: 0, last7Days: [0, 0, 0, 0, 0, 0, 0]);
    }

    // ✅ Trae incidentes y calcula total + serie 7 días
    final incidents = await _fetchAllIncidents();
    return _computeStatsForUser(incidents, userId);
  }

  // ---------------------------------------------------------
  // NETWORK
  // ---------------------------------------------------------
  static Future<List<dynamic>> _fetchAllIncidents() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/incidentes'),
        headers: AuthService.headers,
      );

      if (response.statusCode != 200) {
        return [];
      }

      final decoded = _decodeBody(response.body);

      // soporta: [] ó {data: []}
      if (decoded is List) return decoded;
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        if (data is List) return data;
        final result = decoded['result'];
        if (result is List) return result;
      }
      return [];
    } on SocketException {
      return [];
    } catch (_) {
      return [];
    }
  }

  static dynamic _decodeBody(String body) {
    try {
      if (body.trim().isEmpty) return null;
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------
  // COMPUTATION
  // ---------------------------------------------------------
  static IncidenteStats _computeStatsForUser(List<dynamic> raw, int userId) {
    int total = 0;
    final series = List<int>.filled(7, 0);

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    for (final item in raw) {
      if (item is! Map) continue;

      final incidentUserId = _extractUsuarioId(item);
      if (incidentUserId == null || incidentUserId != userId) continue;

      total++;

      final created = _extractFechaCreacion(item);
      if (created == null) continue;

      final local = created.toLocal();
      final dayStart = DateTime(local.year, local.month, local.day);

      final diffDays = todayStart.difference(dayStart).inDays;
      if (diffDays < 0 || diffDays > 6) continue;

      // series[0]=hace 6 días ... series[6]=hoy
      final index = 6 - diffDays;
      series[index] = series[index] + 1;
    }

    return IncidenteStats(total: total, last7Days: series);
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static int? _extractUsuarioId(Map item) {
    // ✅ casos típicos:
    //  - usuarioId
    //  - usuario_id
    //  - usuario: { id: ... }
    //  - usuario: { usuarioId: ... }
    final direct = _asInt(item['usuarioId']) ?? _asInt(item['usuario_id']);
    if (direct != null) return direct;

    final u = item['usuario'];
    if (u is Map) {
      return _asInt(u['id']) ?? _asInt(u['usuarioId']) ?? _asInt(u['usuario_id']);
    }

    return null;
  }

  static DateTime? _extractFechaCreacion(Map item) {
    // ✅ casos típicos:
    //  - fechaCreacion (OffsetDateTime ISO)
    //  - createdAt
    //  - fecha_creacion
    final s = (item['fechaCreacion'] ??
            item['fecha_creacion'] ??
            item['createdAt'] ??
            item['created_at'])
        ?.toString();

    if (s == null || s.trim().isEmpty) return null;

    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }
}
