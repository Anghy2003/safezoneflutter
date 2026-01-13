import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CommunityMembershipService {
  // baseUrl YA INCLUYE /api
  final String baseUrl;

  CommunityMembershipService({required this.baseUrl});

  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt("userId");
  }

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();

    // Si tu backend usa Spring Security + Firebase, necesitas este token.
    // Asegúrate de guardarlo al login con key "idToken".
    final token = prefs.getString("idToken");

    return {
      "Content-Type": "application/json",
      if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
    };
  }

  // =========================
  // MIS COMUNIDADES (HUB)
  // =========================
  Future<List<Map<String, dynamic>>> myCommunities(int usuarioId) async {
    // ✅ baseUrl ya trae /api, NO agregues /api otra vez
    final uri = Uri.parse("$baseUrl/usuarios/$usuarioId/comunidades");

    try {
      final r = await http
          .get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 18));

      if (r.statusCode >= 200 && r.statusCode < 300) {
        final decoded = jsonDecode(r.body);
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }

      return [
        {"_error": "HTTP_${r.statusCode}", "_detail": r.body}
      ];
    } on SocketException {
      return [
        {"_error": "NO_INTERNET"}
      ];
    } catch (e) {
      return [
        {"_error": "ERROR", "_detail": e.toString()}
      ];
    }
  }

  // =========================
  // ADMIN: LISTAR PENDIENTES
  // =========================
  Future<List<Map<String, dynamic>>> solicitudesPendientes({
    required int comunidadId,
    required int adminId,
  }) async {
    // ✅ sin /api duplicado
    final uri = Uri.parse("$baseUrl/comunidades/$comunidadId/solicitudes/usuario/$adminId");

    try {
      final r = await http
          .get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 18));

      if (r.statusCode >= 200 && r.statusCode < 300) {
        final decoded = jsonDecode(r.body);
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }

      return [
        {"_error": "HTTP_${r.statusCode}", "_detail": r.body}
      ];
    } on SocketException {
      return [
        {"_error": "NO_INTERNET"}
      ];
    } catch (e) {
      return [
        {"_error": "ERROR", "_detail": e.toString()}
      ];
    }
  }

  // =========================
  // ADMIN: APROBAR → TOKEN 24H
  // =========================
  Future<Map<String, dynamic>?> aprobarSolicitud({
    required int comunidadId,
    required int adminId,
    required int usuarioIdSolicitante,
    int horasExpira = 24,
  }) async {
    final uri = Uri.parse(
      "$baseUrl/comunidades/$comunidadId/solicitudes/$usuarioIdSolicitante/aprobar/usuario/$adminId",
    );

    try {
      final r = await http
          .post(
            uri,
            headers: await _headers(),
            body: jsonEncode({"horasExpira": horasExpira}),
          )
          .timeout(const Duration(seconds: 18));

      if (r.statusCode >= 200 && r.statusCode < 300) {
        final decoded = jsonDecode(r.body);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      }

      return {"_error": "HTTP_${r.statusCode}", "_detail": r.body};
    } on SocketException {
      return {"_error": "NO_INTERNET"};
    } catch (e) {
      return {"_error": "ERROR", "_detail": e.toString()};
    }
  }

  Future<bool> rechazarSolicitud({
    required int comunidadId,
    required int adminId,
    required int usuarioIdSolicitante,
  }) async {
    final uri = Uri.parse(
      "$baseUrl/comunidades/$comunidadId/solicitudes/$usuarioIdSolicitante/rechazar/usuario/$adminId",
    );

    try {
      final r = await http
          .post(uri, headers: await _headers())
          .timeout(const Duration(seconds: 18));
      return r.statusCode == 204 || (r.statusCode >= 200 && r.statusCode < 300);
    } catch (_) {
      return false;
    }
  }
}
