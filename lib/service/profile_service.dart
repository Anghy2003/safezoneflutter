// lib/service/profile_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/usuario.dart';
import 'auth_service.dart';

class ProfileService {
  /// ✅ PUT /api/usuarios/{id}
  /// Solo permite editar: nombre, apellido, telefono (y opcionalmente email si quieres)
  static Future<Usuario> updateProfile({
    required int id,
    String? nombre,
    String? apellido,
    String? telefono,
  }) async {
    await AuthService.restoreSession();

    final uri = Uri.parse('${AuthService.baseUrl}/usuarios/$id');

    final body = <String, dynamic>{};

    if (nombre != null && nombre.trim().isNotEmpty) {
      body['nombre'] = nombre.trim();
    }
    if (apellido != null && apellido.trim().isNotEmpty) {
      body['apellido'] = apellido.trim();
    }
    if (telefono != null && telefono.trim().isNotEmpty) {
      body['telefono'] = telefono.trim();
    }

    // ✅ Evita mandar {} (algunos backends lo toleran, otros no)
    if (body.isEmpty) {
      throw Exception('No hay cambios para guardar.');
    }

    final resp = await http.put(
      uri,
      headers: {
        ...AuthService.headers,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (resp.statusCode == 200) {
      final decoded = _safeJson(resp.body);
      final u = _parseUsuario(decoded);
      if (u == null) {
        throw Exception('Respuesta inválida al actualizar perfil.');
      }
      return u;
    }

    // Manejo de error típico
    String msg = 'No se pudo actualizar el perfil (${resp.statusCode})';
    final decoded = _safeJson(resp.body);
    if (decoded is Map<String, dynamic>) {
      final m1 = decoded['message'];
      final m2 = decoded['error'];
      if (m1 is String && m1.isNotEmpty) msg = m1;
      if (m2 is String && m2.isNotEmpty) msg = m2;
    }
    throw Exception(msg);
  }

  static dynamic _safeJson(String body) {
    try {
      if (body.trim().isEmpty) return null;
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  static Usuario? _parseUsuario(dynamic payload) {
    if (payload is! Map<String, dynamic>) return null;

    final u1 = payload['usuario'];
    if (u1 is Map<String, dynamic>) return Usuario.fromJson(u1);

    final u2 = payload['data'];
    if (u2 is Map<String, dynamic>) return Usuario.fromJson(u2);

    final u3 = payload['result'];
    if (u3 is Map<String, dynamic>) return Usuario.fromJson(u3);

    final looksLikeUser = payload.containsKey('id') || payload.containsKey('email');
    if (looksLikeUser) return Usuario.fromJson(payload);

    return null;
  }
}
