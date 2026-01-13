import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/community_card.dart';
import 'auth_service.dart';

class CommunityVerifyService {
  /// LISTAR COMUNIDADES (tarjetas)
  Future<List<CommunityCardModel>> listComunidades({String? query}) async {
    try {
      final q = (query ?? "").trim();

      final uri = Uri.parse("${ApiConfig.baseUrl}/comunidades")
          .replace(queryParameters: q.isEmpty ? null : {"q": q});

      final resp = await http
          .get(uri, headers: AuthService.headers)
          .timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(resp.bodyBytes));

        // Puede venir List directo o {data:[...]}
        final List list = (decoded is List)
            ? decoded
            : (decoded is Map && decoded["data"] is List)
                ? decoded["data"]
                : const [];

        return list
            .whereType<dynamic>()
            .map((e) => CommunityCardModel.fromJson(Map<String, dynamic>.from(e)))
            .where((c) => c.id != 0)
            .toList();
      }

      return [];
    } on SocketException {
      return [];
    } on http.ClientException {
      return [];
    } catch (_) {
      return [];
    }
  }

  /// ✅ CÓDIGO: SOLO REFERENCIAL (ver datos de comunidad)
  /// GET /comunidades/codigo/{codigo}
  Future<Map<String, dynamic>?> verifyCode(String code) async {
    try {
      final c = code.trim();
      if (c.isEmpty) return {"_error": "EMPTY_CODE"};

      final resp = await http
          .get(
            Uri.parse("${ApiConfig.baseUrl}/comunidades/codigo/$c"),
            headers: AuthService.headers,
          )
          .timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        return {"success": true};
      }

      if (resp.statusCode == 404) return {"_error": "NOT_FOUND"};

      return {"_error": "HTTP_${resp.statusCode}"};
    } on SocketException {
      return {"_error": "NO_INTERNET"};
    } on TimeoutException {
      return {"_error": "TIMEOUT"};
    } catch (_) {
      return {"_error": "UNKNOWN"};
    }
  }

  /// ✅ FLUJO PRO: solicitar unirse (pendiente) -> notifica admins
  /// POST /comunidades/{comunidadId}/solicitar-unirse/usuario/{usuarioId}
  Future<Map<String, dynamic>?> requestJoinCommunity({
    required int userId,
    required int communityId,
  }) async {
    try {
      final uri = Uri.parse(
        "${ApiConfig.baseUrl}/comunidades/$communityId/solicitar-unirse/usuario/$userId",
      );

      final resp = await http
          .post(uri, headers: AuthService.headers)
          .timeout(const Duration(seconds: 12));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        return {"success": true};
      }

      if (resp.statusCode == 409) {
        // ya pertenece o ya tiene pendiente
        return {"_error": "CONFLICT"};
      }

      return {"_error": "HTTP_${resp.statusCode}"};
    } on SocketException {
      return {"_error": "NO_INTERNET"};
    } on TimeoutException {
      return {"_error": "TIMEOUT"};
    } catch (_) {
      return {"_error": "UNKNOWN"};
    }
  }

  /// (Opcional) LEGACY: unirse por código directo
  /// POST /comunidades/unirse/{code}/usuario/{userId}
  /// Recomendación: en la UI nueva NO lo uses, usa requestJoinCommunity.
  Future<Map<String, dynamic>?> joinCommunityLegacyByCode({
    required int userId,
    required String code,
  }) async {
    try {
      final c = code.trim();
      if (c.isEmpty) return {"_error": "EMPTY_CODE"};

      final resp = await http
          .post(
            Uri.parse("${ApiConfig.baseUrl}/comunidades/unirse/$c/usuario/$userId"),
            headers: AuthService.headers,
          )
          .timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        return {"success": true};
      }

      if (resp.statusCode == 409) return {"_error": "CONFLICT"};

      return {"_error": "HTTP_${resp.statusCode}"};
    } on SocketException {
      return {"_error": "NO_INTERNET"};
    } on TimeoutException {
      return {"_error": "TIMEOUT"};
    } catch (_) {
      return {"_error": "UNKNOWN"};
    }
  }

  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt("userId");
  }

  /// ✅ unificado
  Future<int?> getCommunityId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt("communityId");
  }

  /// ✅ unificado (tu otro service leía communityId, no comunidadId)
  Future<void> saveCommunityId(int communityId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("communityId", communityId);
  }
}
