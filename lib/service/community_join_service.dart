import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../service/auth_service.dart';

class CommunityJoinService {
  // ✅ userId local
  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt("userId");
  }

  // ✅ guarda comunidad seleccionada (para tu UI)
  Future<void> saveCommunityId(int communityId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("communityId", communityId);
  }

  bool _isConnected(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    if (results.contains(ConnectivityResult.none)) return false;
    return true;
  }

  Future<bool> _hasInternetNow() async {
    final r = await Connectivity().checkConnectivity();
    return _isConnected(r);
  }

  /// POST /api/comunidades/{comunidadId}/solicitar-unirse/usuario/{usuarioId}
  Future<Map<String, dynamic>?> requestJoinCommunity({
    required int userId,
    required int communityId,
  }) async {
    try {
      if (!await _hasInternetNow()) {
        return {"_error": "NO_INTERNET"};
      }

      await AuthService.restoreSession();

      final url = Uri.parse(
        '${ApiConfig.baseUrl}/comunidades/$communityId/solicitar-unirse/usuario/$userId',
      );

      final resp = await http
          .post(
            url,
            headers: {
              ...AuthService.headers,
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return decoded.cast<String, dynamic>();
        return {"success": true};
      }

      // Errores backend típicos
      // 409: ya pendiente / ya activo
      // 404: comunidad no existe
      return {
        "_error": "HTTP_${resp.statusCode}",
        "body": resp.body,
      };
    } on TimeoutException {
      return {"_error": "TIMEOUT"};
    } on SocketException {
      return {"_error": "NO_INTERNET"};
    } catch (_) {
      return {"_error": "UNKNOWN"};
    }
  }
}
