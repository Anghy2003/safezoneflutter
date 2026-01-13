import 'dart:convert';
import 'package:http/http.dart' as http;

class NearbyApi {
  /// Debe venir con /api al final:
  /// ej: https://...run.app/api
  final String baseUrl;
  final Future<String?> Function()? tokenProvider;

  NearbyApi({
    required this.baseUrl,
    this.tokenProvider,
  });

  String _normBase(String b) => b.endsWith('/') ? b.substring(0, b.length - 1) : b;

  Uri _u(String path, [Map<String, dynamic>? qp]) {
    final base = _normBase(baseUrl);

    // path debe iniciar con "/"
    final p = path.startsWith('/') ? path : '/$path';

    final q = <String, String>{};
    qp?.forEach((k, v) {
      if (v == null) return;
      q[k] = v.toString();
    });

    return Uri.parse('$base$p').replace(queryParameters: q);
  }

  Future<Map<String, dynamic>> updateMyLocation({
    required int usuarioId,
    required double lat,
    required double lng,
    int? precision,
  }) async {
    final token = await tokenProvider?.call();

    // ✅ SIN /api aquí
    final uri = _u('/ubicaciones-usuario/actual', {
      'usuarioId': usuarioId,
      'lat': lat,
      'lng': lng,
      if (precision != null) 'precision': precision,
    });

    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('updateMyLocation ${resp.statusCode}: ${resp.body}');
    }

    if (resp.body.trim().isEmpty) return {'ok': true};

    final jsonBody = json.decode(resp.body);
    if (jsonBody is Map<String, dynamic>) return jsonBody;
    return {'ok': true};
  }

  Future<List<Map<String, dynamic>>> fetchNearbyUsers({
    required double lat,
    required double lng,
    double radio = 500,
    int lastMinutes = 20,
    int limit = 200,
  }) async {
    final token = await tokenProvider?.call();

    // ✅ SIN /api aquí
    final uri = _u('/usuarios-cercanos', {
      'lat': lat,
      'lng': lng,
      'radio': radio,
      'lastMinutes': lastMinutes,
      'limit': limit,
    });

    final resp = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('fetchNearbyUsers ${resp.statusCode}: ${resp.body}');
    }

    final body = resp.body.trim();
    if (body.isEmpty) return [];

    final data = json.decode(body);
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }
}
