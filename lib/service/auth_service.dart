// lib/services/auth_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/usuario.dart';

class AuthService {
  static const String baseUrl = 'http://192.168.3.25:8080/api';

  // =========================================================
  //  AUTH MODE (evita mezclar Google vs Login normal)
  // =========================================================
  static const String _kAuthMode = 'authMode'; // 'legacy' | 'google'
  static const String _modeLegacy = 'legacy';
  static const String _modeGoogle = 'google';

  // Keys prefs
  static const String _kUserId = 'userId';
  static const String _kCommunityId = 'communityId';

  // =========================================================
  //  HEADERS (SIEMPRE): X-User-Id para legacy, Bearer solo si modo google
  // =========================================================
  static const Map<String, String> _baseHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static String? _bearerToken; // Firebase ID token
  static int? _legacyUserId; // userId backend (login normal / supabase)

  static int? _cachedUserId;
  static int? _cachedCommunityId;

  static String _authMode = _modeLegacy; // cache en memoria

  /// ✅ Sesión activa: SOLO depende de que exista userId guardado.
  /// (SafeZone entra rápido; solo pide login si se hizo logout)
  static bool get hasSession =>
      _legacyUserId != null || _cachedUserId != null;

  static int? get legacyUserId => _legacyUserId;
  static String get authMode => _authMode;

  static Map<String, String> get headers {
    final h = <String, String>{..._baseHeaders};

    // ✅ Solo manda Bearer si el modo es GOOGLE
    if (_authMode == _modeGoogle &&
        _bearerToken != null &&
        _bearerToken!.isNotEmpty) {
      h['Authorization'] = 'Bearer $_bearerToken';
    }

    // ✅ Legacy manda X-User-Id (sirve también para Google si tu backend lo usa)
    if (_legacyUserId != null) {
      h['X-User-Id'] = _legacyUserId.toString();
    }

    return h;
  }

  // =========================================================
  //  HELPERS
  // =========================================================
  static dynamic _decodeBody(String body) {
    try {
      if (body.trim().isEmpty) return null;
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  static String? _extractMessage(http.Response r) {
    final decoded = _decodeBody(r.body);
    if (decoded is Map<String, dynamic> && decoded['message'] != null) {
      return decoded['message'].toString();
    }
    return null;
  }

  /// ✅ FIX CLAVE:
  /// Soporta payloads:
  /// - { usuario: {...} }
  /// - { data: {...} }
  /// - { result: {...} }
  /// - usuario plano { id, email, ... }
  static Usuario? _parseUsuario(dynamic payload) {
    if (payload is! Map<String, dynamic>) return null;

    // Caso 1: { usuario: {...} }
    final u1 = payload['usuario'];
    if (u1 is Map<String, dynamic>) return Usuario.fromJson(u1);

    // Caso 2: { data: {...} }
    final u2 = payload['data'];
    if (u2 is Map<String, dynamic>) return Usuario.fromJson(u2);

    // Caso 3: { result: {...} }
    final u3 = payload['result'];
    if (u3 is Map<String, dynamic>) return Usuario.fromJson(u3);

    // Caso 4: usuario plano
    final looksLikeUser = payload.containsKey('id') || payload.containsKey('email');
    if (looksLikeUser) return Usuario.fromJson(payload);

    return null;
  }

  static Future<void> _setAuthMode(String mode) async {
    _authMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAuthMode, mode);
  }

  static void _attachLegacySessionHeadersSync(int userId) {
    _legacyUserId = userId;
  }

  static void _clearLegacySessionHeadersSync() {
    _legacyUserId = null;
  }

  // =========================================================
  //  FIREBASE (SOLO PARA GOOGLE)
  // =========================================================
  static Future<String?> getFirebaseIdToken({bool forceRefresh = true}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      return await user.getIdToken(forceRefresh);
    } catch (_) {
      return null;
    }
  }

  static Future<void> attachFirebaseSession({bool forceRefreshToken = true}) async {
    final token = await getFirebaseIdToken(forceRefresh: forceRefreshToken);
    if (token == null || token.isEmpty) {
      _bearerToken = null;
      return;
    }
    _bearerToken = token;
  }

   // =========================================================
  //  PERFIL: GET /api/usuarios/me
  // =========================================================
  static Future<Map<String, dynamic>> backendMe() async {
    try {
      // ✅ FIX: si estás en modo LEGACY, NO llames /usuarios/me (requiere Firebase)
      if (_authMode == _modeLegacy) {
        final id = await getCurrentUserId();
        if (id == null) {
          return {'success': false, 'message': 'Sin sesión legacy'};
        }
        // Sesión legacy se valida por prefs (userId)
        return {'success': true, 'message': 'Sesión legacy OK', 'userId': id};
      }

      // ✅ Google mode: aquí sí aplica /usuarios/me
      final response = await http.get(
        Uri.parse('$baseUrl/usuarios/me'),
        headers: AuthService.headers,
      );

      if (response.statusCode == 200) {
        final decoded = _decodeBody(response.body);
        final usuario = _parseUsuario(decoded);
        if (usuario == null) {
          return {
            'success': false,
            'message': 'Respuesta inválida del servidor (/usuarios/me)',
          };
        }
        await _saveUserData(usuario);
        return {'success': true, 'usuario': usuario};
      }

      // ✅ Solo reintenta refresh si estás en modo GOOGLE
      if (response.statusCode == 401 &&
          _authMode == _modeGoogle &&
          FirebaseAuth.instance.currentUser != null) {
        await attachFirebaseSession(forceRefreshToken: true);

        final retry = await http.get(
          Uri.parse('$baseUrl/usuarios/me'),
          headers: AuthService.headers,
        );

        if (retry.statusCode == 200) {
          final decoded = _decodeBody(retry.body);
          final usuario = _parseUsuario(decoded);
          if (usuario == null) {
            return {
              'success': false,
              'message': 'Respuesta inválida del servidor (/usuarios/me)',
            };
          }
          await _saveUserData(usuario);
          return {'success': true, 'usuario': usuario};
        }
      }

      final msg = _extractMessage(response) ??
          'Sesión no válida o sin permisos (${response.statusCode})';
      return {'success': false, 'message': msg};
    } on SocketException {
      return {'success': false, 'message': 'No hay conexión a internet'};
    } catch (e) {
      return {'success': false, 'message': 'Error inesperado: $e'};
    }
  }


  // =========================================================
  //  REGISTRO LEGACY
  // =========================================================
  static Future<Map<String, dynamic>> registrar({
    required String nombre,
    required String apellido,
    required String email,
    required String telefono,
    required String password,
    String? fotoUrl,
  }) async {
    try {
      // ✅ En registro legacy: no mezclar con Google
      await _setAuthMode(_modeLegacy);
      _bearerToken = null;
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}

      final body = <String, dynamic>{
        'nombre': nombre.trim(),
        'apellido': apellido.trim(),
        'email': email.trim(),
        'telefono': telefono.trim(),
        'passwordHash': password,
        if (fotoUrl != null && fotoUrl.trim().isNotEmpty) 'fotoUrl': fotoUrl.trim(),
      };

      final response = await http.post(
        Uri.parse('$baseUrl/usuarios'),
        headers: AuthService.headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final decoded = _decodeBody(response.body);
        final usuario = _parseUsuario(decoded);
        if (usuario == null) {
          return {'success': false, 'message': 'Respuesta inválida del servidor (registro)'};
        }

        await _saveUserData(usuario);
        if (usuario.id != null) {
          _attachLegacySessionHeadersSync(usuario.id!);
        }

        return {'success': true, 'message': 'Registro exitoso', 'usuario': usuario};
      }

      if (response.statusCode == 409) {
        return {
          'success': false,
          'message': _extractMessage(response) ?? 'Ese correo ya está registrado'
        };
      }

      if (response.statusCode == 400) {
        return {'success': false, 'message': _extractMessage(response) ?? 'Datos inválidos'};
      }

      return {
        'success': false,
        'message': _extractMessage(response) ?? 'Error registrando (${response.statusCode})',
      };
    } on SocketException {
      return {'success': false, 'message': 'No hay conexión a internet'};
    } catch (e) {
      return {'success': false, 'message': 'Error inesperado: $e'};
    }
  }

  // =========================================================
  //  LOGIN EMAIL/PASSWORD (LEGACY)
  // =========================================================
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      // ✅ Legacy: no mezclar con Firebase
      await _setAuthMode(_modeLegacy);
      _bearerToken = null;
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}

      final body = {'email': email.trim(), 'password': password};

      final response = await http.post(
        Uri.parse('$baseUrl/usuarios/login'),
        headers: AuthService.headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final decoded = _decodeBody(response.body);
        final usuario = _parseUsuario(decoded);
        if (usuario == null) {
          return {'success': false, 'message': 'Respuesta inválida del servidor (login)'};
        }

        await _saveUserData(usuario);
        if (usuario.id != null) {
          _attachLegacySessionHeadersSync(usuario.id!);
        }

        return {
          'success': true,
          'message': 'Inicio de sesión exitoso',
          'usuario': usuario,
        };
      }

      if (response.statusCode == 401) {
        return {
          'success': false,
          'message': _extractMessage(response) ?? 'Credenciales incorrectas',
        };
      }

      return {
        'success': false,
        'message': _extractMessage(response) ?? 'Error en login (${response.statusCode})',
      };
    } on SocketException {
      return {'success': false, 'message': 'No hay conexión a internet'};
    } catch (e) {
      return {'success': false, 'message': 'Error inesperado: $e'};
    }
  }

  // =========================================================
  //  LOGIN GOOGLE (FIREBASE)
  // =========================================================
  static Future<Map<String, dynamic>> loginWithFirebaseGoogle() async {
    try {
      await _setAuthMode(_modeGoogle);
      await attachFirebaseSession(forceRefreshToken: true);

      if (_bearerToken == null || _bearerToken!.isEmpty) {
        return {
          'success': false,
          'message': 'No hay sesión Firebase. Inicia sesión con Google primero.',
        };
      }

      final response = await http.post(
        Uri.parse('$baseUrl/usuarios/google-login'),
        headers: AuthService.headers,
      );

      if (response.statusCode == 200) {
        final decoded = _decodeBody(response.body);
        final usuario = _parseUsuario(decoded);
        if (usuario == null) {
          return {'success': false, 'message': 'Respuesta inválida del servidor (google-login)'};
        }

        await _saveUserData(usuario);
        if (usuario.id != null) {
          _attachLegacySessionHeadersSync(usuario.id!);
        }

        return {
          'success': true,
          'registered': true,
          'message': 'Google OK y usuario registrado',
          'usuario': usuario,
        };
      }

      if (response.statusCode == 409) {
        final decoded = _decodeBody(response.body);
        final email = (decoded is Map<String, dynamic> && decoded['email'] != null)
            ? decoded['email'].toString()
            : FirebaseAuth.instance.currentUser?.email;

        return {
          'success': false,
          'registered': false,
          'email': email,
          'message': _extractMessage(response) ??
              'Correo verificado con Google, pero falta registro legal.',
        };
      }

      if (response.statusCode == 401) {
        await attachFirebaseSession(forceRefreshToken: true);
        return {'success': false, 'message': 'Token Firebase inválido o expirado'};
      }

      return {
        'success': false,
        'message': _extractMessage(response) ?? 'Error google-login (${response.statusCode})',
      };
    } on SocketException {
      return {'success': false, 'message': 'No hay conexión a internet'};
    } catch (e) {
      return {'success': false, 'message': 'Error inesperado: $e'};
    }
  }

  // =========================================================
  //  FCM TOKEN
  // =========================================================
  static Future<Map<String, dynamic>> updateFcmToken({
    required int userId,
    required String token,
    String? deviceInfo,
  }) async {
    try {
      if (token.trim().isEmpty) {
        return {'success': false, 'message': 'token es obligatorio'};
      }

      final body = {
        'token': token.trim(),
        if (deviceInfo != null && deviceInfo.trim().isNotEmpty) 'deviceInfo': deviceInfo.trim(),
      };

      final response = await http.put(
        Uri.parse('$baseUrl/usuarios/$userId/fcm-token'),
        headers: AuthService.headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final decoded = _decodeBody(response.body);
        final usuario = _parseUsuario(decoded);
        if (usuario != null) await _saveUserData(usuario);
        return {'success': true, 'usuario': usuario};
      }

      if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'No autorizado (401). Revisa sesión / headers.',
        };
      }

      if (response.statusCode == 403) {
        return {'success': false, 'message': _extractMessage(response) ?? 'No autorizado (403)'};
      }

      return {
        'success': false,
        'message': _extractMessage(response) ?? 'Error actualizando FCM (${response.statusCode})',
      };
    } on SocketException {
      return {'success': false, 'message': 'No hay conexión a internet'};
    } catch (e) {
      return {'success': false, 'message': 'Error inesperado: $e'};
    }
  }

  // =========================================================
  //  STORAGE / SESSION
  // =========================================================
  static Future<void> _saveUserData(Usuario usuario) async {
    final prefs = await SharedPreferences.getInstance();

    if (usuario.id != null) {
      _cachedUserId = usuario.id;
      _attachLegacySessionHeadersSync(usuario.id!); // ✅ clave: mantener sesión activa
      await prefs.setInt(_kUserId, usuario.id!);
    }

    try {
      final communityId = usuario.comunidadId;
      if (communityId != null) {
        _cachedCommunityId = communityId;
        await prefs.setInt(_kCommunityId, communityId);
      } else {
        _cachedCommunityId = null;
        await prefs.remove(_kCommunityId);
      }
    } catch (_) {}
  }

  static Future<int?> getCurrentUserId() async {
    if (_cachedUserId != null) return _cachedUserId;

    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_kUserId);
    if (id != null) {
      _cachedUserId = id;
      _attachLegacySessionHeadersSync(id);
    }
    return id;
  }

  static Future<int?> getCurrentCommunityId() async {
    if (_cachedCommunityId != null) return _cachedCommunityId;

    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_kCommunityId);
    _cachedCommunityId = id;
    return id;
  }

  /// Llamar al iniciar la app:
  /// - reconstruye X-User-Id desde prefs
  /// - y si el modo es google, también Bearer
  static Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();

    _authMode = prefs.getString(_kAuthMode) ?? _modeLegacy;

    final id = prefs.getInt(_kUserId);
    if (id != null) {
      _cachedUserId = id;
      _attachLegacySessionHeadersSync(id);
    } else {
      _cachedUserId = null;
      _clearLegacySessionHeadersSync();
    }

    final communityId = prefs.getInt(_kCommunityId);
    _cachedCommunityId = communityId;

    if (_authMode == _modeGoogle && FirebaseAuth.instance.currentUser != null) {
      await attachFirebaseSession(forceRefreshToken: false);
    } else {
      _bearerToken = null;
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserId);
    await prefs.remove(_kCommunityId);
    await prefs.remove(_kAuthMode);

    _cachedUserId = null;
    _cachedCommunityId = null;
    _legacyUserId = null;
    _bearerToken = null;
    _authMode = _modeLegacy;

    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }

  // =========================================================
  //  ERROR MAPPING (FIREBASE)
  // =========================================================
  static String mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'Ya existe una cuenta con otro método. Intenta con email/contraseña o el método correcto.';
      case 'invalid-credential':
        return 'Credenciales inválidas o expiradas.';
      case 'network-request-failed':
        return 'Error de red. Verifica tu conexión.';
      default:
        return 'Error Google/Firebase: ${e.message ?? e.code}';
    }
  }
}
