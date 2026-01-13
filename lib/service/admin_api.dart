// lib/service/admin_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class AdminApi {
  static String get baseUrl => ApiConfig.baseUrl; // ej: https://...run.app/api

  // ====== helpers ======
  static Future<int?> _userId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('userId');
    return id;
  }

  static Uri _u(String path) {
    // path debe empezar con "/"
    return Uri.parse('$baseUrl$path');
  }

  static Map<String, String> _headers() => const {
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      };

  static dynamic _decode(http.Response r) {
    if (r.body.isEmpty) return null;
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  static Exception _err(http.Response r) {
    try {
      final j = _decode(r);
      if (j is Map && j['message'] != null) {
        return Exception(j['message'].toString());
      }
      return Exception('HTTP ${r.statusCode}: ${r.body}');
    } catch (_) {
      return Exception('HTTP ${r.statusCode}: ${r.body}');
    }
  }

  // ====== genéricos ======

  static Future<List<dynamic>> getList(String path) async {
    final res = await http.get(_u(path), headers: _headers());
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = _decode(res);
      if (body is List) return body;
      throw Exception('Respuesta inválida (se esperaba lista)');
    }
    throw _err(res);
  }

  static Future<Map<String, dynamic>> getMap(String path) async {
    final res = await http.get(_u(path), headers: _headers());
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = _decode(res);
      if (body is Map<String, dynamic>) return body;
      if (body is Map) return body.cast<String, dynamic>();
      throw Exception('Respuesta inválida (se esperaba objeto)');
    }
    throw _err(res);
  }

  static Future<Map<String, dynamic>> post(String path, {Object? body}) async {
    final res = await http.post(
      _u(path),
      headers: _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = _decode(res);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
      // si el backend devuelve vacío, regresa {}
      return <String, dynamic>{};
    }
    throw _err(res);
  }

  static Future<void> delete(String path) async {
    final res = await http.delete(_u(path), headers: _headers());
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw _err(res);
  }

  // ====== endpoints de comunidades (con usuarioId) ======

  static Future<List<Map<String, dynamic>>> listarComunidades() async {
    final data = await getList('/comunidades');
    return data.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> aprobarComunidad(int comunidadId) async {
    final uid = await _userId();
    if (uid == null) throw Exception('Sesión inválida: userId no encontrado');

    // ✅ backend real
    return post('/comunidades/$comunidadId/aprobar/usuario/$uid');
  }

  static Future<Map<String, dynamic>> crearComunidad(Map<String, dynamic> comunidad) async {
    final uid = await _userId();
    if (uid == null) throw Exception('Sesión inválida: userId no encontrado');

    // ✅ backend: POST /comunidades/usuario/{usuarioId}
    return post('/comunidades/usuario/$uid', body: comunidad);
  }

  static Future<Map<String, dynamic>> actualizarComunidad(int id, Map<String, dynamic> comunidad) async {
    final uid = await _userId();
    if (uid == null) throw Exception('Sesión inválida: userId no encontrado');

    // ✅ backend: PUT /comunidades/{id}/usuario/{usuarioId}
    final res = await http.put(
      _u('/comunidades/$id/usuario/$uid'),
      headers: _headers(),
      body: jsonEncode(comunidad),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = _decode(res);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
      return <String, dynamic>{};
    }
    throw _err(res);
  }

  static Future<void> eliminarComunidad(int id) async {
    final uid = await _userId();
    if (uid == null) throw Exception('Sesión inválida: userId no encontrado');

    // ✅ backend: DELETE /comunidades/{id}/usuario/{usuarioId}
    await delete('/comunidades/$id/usuario/$uid');
  }

  static Future<Map<String, dynamic>> buscarPorCodigo(String codigo) async {
    // ✅ backend: GET /comunidades/codigo/{codigo}
    return getMap('/comunidades/codigo/$codigo');
  }

  static Future<Map<String, dynamic>> unirsePorCodigo(String codigo, int usuarioId) async {
    // ✅ backend: POST /comunidades/unirse/{codigoAcceso}/usuario/{usuarioId}
    return post('/comunidades/unirse/$codigo/usuario/$usuarioId');
  }
}
