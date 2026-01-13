import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CommunityAdminRequestsService {

  final String baseUrl;

  CommunityAdminRequestsService({required this.baseUrl});

  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    // key correcta según tu AuthService
    return prefs.getInt("userId");
  }

  /// ✅ FIX: tu app usa "comunidadId" (no "communityId")
  Future<int?> getCommunityId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt("comunidadId") ?? prefs.getInt("communityId");
  }

  /// ✅ FIX: no depender solo de flag cacheado
  Future<bool> isAdminCommunity() async {
    final prefs = await SharedPreferences.getInstance();

    final flag = prefs.getBool("isAdminComunidad") ?? false;
    if (flag) return true;

    final role = (prefs.getString("communityRole") ?? '').trim().toUpperCase();
    if (role == 'ADMIN' || role == 'ADMIN_COMUNIDAD') return true;

    final email = (prefs.getString("userEmail") ?? '').trim().toLowerCase();
    if (email == 'safezonecomunity@gmail.com') return true;

    return false;
  }

  Future<bool> _hasInternetNow() async {
    try {
      final r = await Connectivity().checkConnectivity();
      return r != ConnectivityResult.none;
    } catch (_) {
      return true;
    }
  }

  /// GET  {baseUrl}/comunidades/{comunidadId}/solicitudes/usuario/{adminId}
  Future<List<Map<String, dynamic>>> listPendingRequests({
    required int adminId,
    required int comunidadId,
  }) async {
    final online = await _hasInternetNow();
    if (!online) return [{"_error": "NO_INTERNET"}];

    final uri = Uri.parse(
      "$baseUrl/comunidades/$comunidadId/solicitudes/usuario/$adminId",
    );

    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 18));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
        return [];
      }

      String? msg;
      try {
        final body = jsonDecode(utf8.decode(resp.bodyBytes));
        if (body is Map && body["message"] != null) msg = body["message"].toString();
      } catch (_) {}

      return [
        {
          "_error": "HTTP_${resp.statusCode}",
          if (msg != null) "message": msg,
        }
      ];
    } on SocketException {
      return [{"_error": "NO_INTERNET"}];
    } on FormatException {
      return [{"_error": "BAD_JSON"}];
    } catch (_) {
      return [{"_error": "UNKNOWN"}];
    }
  }

  /// POST {baseUrl}/comunidades/{comunidadId}/solicitudes/{usuarioId}/aprobar/usuario/{adminId}
  Future<Map<String, dynamic>> approve({
    required int adminId,
    required int comunidadId,
    required int usuarioId,
  }) async {
    final online = await _hasInternetNow();
    if (!online) return {"_error": "NO_INTERNET"};

    final uri = Uri.parse(
      "$baseUrl/comunidades/$comunidadId/solicitudes/$usuarioId/aprobar/usuario/$adminId",
    );

    try {
      final resp = await http.post(uri).timeout(const Duration(seconds: 18));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        if (resp.bodyBytes.isEmpty) return {"success": true};
        final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        return {"success": true};
      }

      String? msg;
      try {
        final body = jsonDecode(utf8.decode(resp.bodyBytes));
        if (body is Map && body["message"] != null) msg = body["message"].toString();
      } catch (_) {}

      return {
        "_error": "HTTP_${resp.statusCode}",
        if (msg != null) "message": msg,
      };
    } catch (_) {
      return {"_error": "UNKNOWN"};
    }
  }

  /// POST {baseUrl}/comunidades/{comunidadId}/solicitudes/{usuarioId}/rechazar/usuario/{adminId}
  Future<Map<String, dynamic>> reject({
    required int adminId,
    required int comunidadId,
    required int usuarioId,
  }) async {
    final online = await _hasInternetNow();
    if (!online) return {"_error": "NO_INTERNET"};

    final uri = Uri.parse(
      "$baseUrl/comunidades/$comunidadId/solicitudes/$usuarioId/rechazar/usuario/$adminId",
    );

    try {
      final resp = await http.post(uri).timeout(const Duration(seconds: 18));

      if (resp.statusCode == 204) return {"success": true};
      if (resp.statusCode >= 200 && resp.statusCode < 300) return {"success": true};

      String? msg;
      try {
        final body = jsonDecode(utf8.decode(resp.bodyBytes));
        if (body is Map && body["message"] != null) msg = body["message"].toString();
      } catch (_) {}

      return {
        "_error": "HTTP_${resp.statusCode}",
        if (msg != null) "message": msg,
      };
    } catch (_) {
      return {"_error": "UNKNOWN"};
    }
  }
}
