import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/notificacion_api.dart';
import '../config/api_config.dart';

class NotificacionesService {
  /// ✅ Sin backend: traemos TODAS y filtramos por comunidadId en cliente
  Future<List<NotificacionApi>> listarPorComunidad({
    required int comunidadId,
  }) async {
    final uri = Uri.parse("${ApiConfig.baseUrl}/notificaciones");

    final res = await http.get(
      uri,
      headers: const {"Content-Type": "application/json"},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("HTTP ${res.statusCode}: ${res.body}");
    }

    final decoded = json.decode(res.body);
    final List list = decoded is List ? decoded : [];

    final items = list
        .whereType<Map<String, dynamic>>()
        .map(NotificacionApi.fromJson)
        // ✅ filtramos en el cliente por comunidad
        .where((n) => n.comunidadId == null || n.comunidadId == comunidadId)
        .toList();

    // ✅ más recientes primero (si hay fecha)
    items.sort((a, b) {
      final da = a.fecha?.millisecondsSinceEpoch ?? 0;
      final db = b.fecha?.millisecondsSinceEpoch ?? 0;
      return db.compareTo(da);
    });

    return items;
  }
}
