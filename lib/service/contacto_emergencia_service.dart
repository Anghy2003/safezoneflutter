// lib/service/contacto_emergencia_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/contacto_emergencia.dart';
import 'auth_service.dart';

class ContactoEmergenciaService {
  static String get _baseUrl => ApiConfig.baseUrl; // ✅ https://.../api

  // =========================
  // Helpers
  // =========================
  static dynamic _decodeBody(String body) {
    try {
      if (body.trim().isEmpty) return null;
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  static String _extractMessage(http.Response r) {
    final decoded = _decodeBody(r.body);
    if (decoded is Map<String, dynamic>) {
      final msg = decoded['message'];
      if (msg != null) return msg.toString();
      final err = decoded['error'];
      if (err != null) return err.toString();
    }
    return r.body.isNotEmpty ? r.body : 'Error HTTP ${r.statusCode}';
  }

  /// ✅ Headers SIEMPRE con X-User-Id (tu backend lo exige)
  static Future<Map<String, String>> _headersWithUserId() async {
    // No uses restoreSession directo en cada request si puedes evitarlo
    await AuthService.ensureRestored();

    final h = <String, String>{
      ...AuthService.headers, // puede traer Authorization o X-User-Id dependiendo del modo
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // 🔒 Forzar X-User-Id porque /contactos-emergencia/mios lo exige
    final userId = await AuthService.getCurrentUserId();
    if (userId == null || userId <= 0) {
      throw Exception('Sesión inválida: no se encontró userId para X-User-Id.');
    }
    h['X-User-Id'] = userId.toString();

    return h;
  }

  // =========================
  // GET /api/contactos-emergencia/mios
  // =========================
  static Future<List<ContactoEmergencia>> getMisContactosActivos() async {
    try {
      final headers = await _headersWithUserId();

      final resp = await http.get(
        Uri.parse('$_baseUrl/contactos-emergencia/mios'),
        headers: headers,
      );

      if (resp.statusCode == 200) {
        final decoded = _decodeBody(resp.body);

        // ✅ Soporta: lista directa o map con lista dentro
        dynamic listPayload = decoded;

        if (decoded is Map<String, dynamic>) {
          listPayload = decoded['data'] ??
              decoded['contactos'] ??
              decoded['result'] ??
              decoded['items'];
        }

        if (listPayload is! List) {
          // Si el backend devuelve vacío como {}, lo tratamos como lista vacía
          if (listPayload == null) return <ContactoEmergencia>[];
          throw Exception('Formato inesperado del backend al listar contactos.');
        }

        return listPayload
            .whereType<Map>()
            .map((e) =>
                ContactoEmergencia.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      if (resp.statusCode == 401 || resp.statusCode == 403) {
        throw Exception(
          'No autorizado (${resp.statusCode}). ${_extractMessage(resp)}',
        );
      }

      throw Exception(
        'Error al obtener contactos (${resp.statusCode}): ${_extractMessage(resp)}',
      );
    } on SocketException {
      throw Exception('Sin conexión a internet');
    } catch (e) {
      throw Exception('Error al obtener contactos: $e');
    }
  }

  // =========================
  // POST /api/contactos-emergencia
  // =========================
  static Future<ContactoEmergencia> createContacto({
    required String nombre,
    required String telefono,
    String? relacion,
    int prioridad = 1,
    String? fotoUrl,
  }) async {
    try {
      final headers = await _headersWithUserId();

      // ⚠️ NO envíes usuarioId (tu backend asigna por header)
      final body = <String, dynamic>{
        'nombre': nombre.trim(),
        'telefono': telefono.trim(),
        if (relacion != null && relacion.trim().isNotEmpty)
          'relacion': relacion.trim(),
        'prioridad': prioridad,
        if (fotoUrl != null && fotoUrl.trim().isNotEmpty)
          'fotoUrl': fotoUrl.trim(),
        'activo': true,
      };

      final resp = await http.post(
        Uri.parse('$_baseUrl/contactos-emergencia'),
        headers: headers,
        body: jsonEncode(body),
      );

      if (resp.statusCode == 201 || resp.statusCode == 200) {
        final decoded = _decodeBody(resp.body);

        // ✅ Soporta: map directo o map dentro de data/result
        Map<String, dynamic>? payload;
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('data') && decoded['data'] is Map) {
            payload = Map<String, dynamic>.from(decoded['data']);
          } else if (decoded.containsKey('result') && decoded['result'] is Map) {
            payload = Map<String, dynamic>.from(decoded['result']);
          } else {
            payload = decoded;
          }
        }

        if (payload == null) {
          throw Exception('Formato inesperado al crear contacto.');
        }

        return ContactoEmergencia.fromJson(payload);
      }

      if (resp.statusCode == 401 || resp.statusCode == 403) {
        throw Exception(
          'No autorizado (${resp.statusCode}). ${_extractMessage(resp)}',
        );
      }

      throw Exception(
        'Error al crear contacto (${resp.statusCode}): ${_extractMessage(resp)}',
      );
    } on SocketException {
      throw Exception('Sin conexión a internet');
    } catch (e) {
      throw Exception('Error al crear contacto: $e');
    }
  }

  // =========================
  // DELETE /api/contactos-emergencia/{id}
  // =========================
  static Future<void> deleteContacto(int id) async {
    try {
      final headers = await _headersWithUserId();

      final resp = await http.delete(
        Uri.parse('$_baseUrl/contactos-emergencia/$id'),
        headers: headers,
      );

      if (resp.statusCode == 204 || resp.statusCode == 200) return;

      if (resp.statusCode == 401 || resp.statusCode == 403) {
        throw Exception(
          'No autorizado (${resp.statusCode}). ${_extractMessage(resp)}',
        );
      }
      if (resp.statusCode == 404) {
        throw Exception('Contacto no encontrado.');
      }

      throw Exception(
        'Error al eliminar (${resp.statusCode}): ${_extractMessage(resp)}',
      );
    } on SocketException {
      throw Exception('Sin conexión a internet');
    } catch (e) {
      throw Exception('Error al eliminar contacto: $e');
    }
  }
}
