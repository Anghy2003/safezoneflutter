// lib/service/auth_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/usuario.dart';
import '../routes/app_routes.dart';

class AuthService {
  static String get baseUrl => ApiConfig.baseUrl;

  static const String superAdminEmail = "safezonecomunity@gmail.com";

  // =========================================================
  //  AUTH MODE
  // =========================================================
  static const String _kAuthMode = 'authMode'; // 'legacy' | 'google'
  static const String _modeLegacy = 'legacy';
  static const String _modeGoogle = 'google';

  // ✅ keys oficiales
  static const String _kUserId = 'userId';
  static const String _kCommunityId = 'communityId';
  static const String _kUserRole = 'userRole';
  static const String _kUserEmail = 'userEmail';
  static const String _kCommunityRole = 'communityRole';

  // ✅ compat con tus keys actuales (UI)
  static const String _kActiveCommunityIdCompat = 'comunidadId';
  static const String _kIsAdminComunidadCompat = 'isAdminComunidad';

  // ✅ UI cache keys (tu menú/home usa estas)
  static const String _kDisplayNameUi = 'displayName';
  static const String _kPhotoUrlUi = 'photoUrl';
  static const String _kEmailUi = 'email'; // algunas pantallas usan 'email'
  static const String _kComunidadNombreUi = 'comunidadNombre';
  static const String _kComunidadFotoUrlUi = 'comunidadFotoUrl';

  // =========================================================
  //  HEADERS
  // =========================================================
  static const Map<String, String> _baseHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static String? _bearerToken;
  static int? _legacyUserId;

  static int? _cachedUserId;
  static int? _cachedCommunityId;

  static String? _cachedUserRole;
  static String? _cachedUserEmail;
  static String? _cachedCommunityRole;

  static String _authMode = _modeLegacy;

  // ✅ restore guard
  static bool _restored = false;

  // =========================================================
  //  GETTERS
  // =========================================================
  static bool get hasLocalSession =>
      (_cachedUserId != null && (_cachedUserId ?? 0) > 0) ||
      (_legacyUserId != null && (_legacyUserId ?? 0) > 0);

  static bool get hasSession => hasLocalSession;

  static int? get legacyUserId => _legacyUserId;
  static String get authMode => _authMode;

  static bool get isAdmin => (_cachedUserRole ?? '').toUpperCase() == 'ADMIN';

  static Map<String, String> get headers {
    final h = <String, String>{..._baseHeaders};

    // ✅ Google => bearer
    if (_authMode == _modeGoogle &&
        _bearerToken != null &&
        _bearerToken!.isNotEmpty) {
      h['Authorization'] = 'Bearer $_bearerToken';
    }

    // ✅ Legacy => X-User-Id (NO mezclar)
    if (_authMode == _modeLegacy && _legacyUserId != null) {
      h['X-User-Id'] = _legacyUserId.toString();
    }

    return h;
  }

  // =========================================================
  //  CONNECTIVITY
  // =========================================================
  static Future<bool> isOnline() async {
    try {
      final r = await Connectivity().checkConnectivity();
      return r != ConnectivityResult.none;
    } catch (_) {
      // ✅ fallback seguro: si no puedo saber, trato como OFFLINE
      return false;
    }
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

  static Usuario? _parseUsuario(dynamic payload) {
    if (payload is! Map<String, dynamic>) return null;

    final u1 = payload['usuario'];
    if (u1 is Map<String, dynamic>) return Usuario.fromJson(u1);

    final u2 = payload['data'];
    if (u2 is Map<String, dynamic>) return Usuario.fromJson(u2);

    final u3 = payload['result'];
    if (u3 is Map<String, dynamic>) return Usuario.fromJson(u3);

    final looksLikeUser =
        payload.containsKey('id') || payload.containsKey('email');
    if (looksLikeUser) return Usuario.fromJson(payload);

    return null;
  }

  static Future<void> _setAuthMode(String mode) async {
    _authMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAuthMode, mode);

    // ✅ evita sesiones híbridas
    if (mode == _modeGoogle) {
      _legacyUserId = null;
    } else {
      _bearerToken = null;
    }
  }

  static void _attachLegacySessionHeadersSync(int userId) {
    _legacyUserId = userId;
  }

  static void _clearLegacySessionHeadersSync() {
    _legacyUserId = null;
  }

  // =========================================================
  //  RESTORE SESSION (offline-safe)
  // =========================================================
  static Future<void> ensureRestored() async {
    if (_restored) return;
    await restoreSession();
    _restored = true;
  }

  static Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();

    _authMode = prefs.getString(_kAuthMode) ?? _modeLegacy;

    final id = prefs.getInt(_kUserId);
    if (id != null && id > 0) {
      _cachedUserId = id;

      // ✅ SOLO legacy usa X-User-Id (NO mezclar con Google)
      if (_authMode == _modeLegacy) {
        _attachLegacySessionHeadersSync(id);
      } else {
        _clearLegacySessionHeadersSync();
      }
    } else {
      _cachedUserId = null;
      _clearLegacySessionHeadersSync();
    }

    // ✅ communityId: soporta key oficial y compat
    _cachedCommunityId =
        prefs.getInt(_kCommunityId) ?? prefs.getInt(_kActiveCommunityIdCompat);

    _cachedUserRole = prefs.getString(_kUserRole);
    _cachedUserEmail = prefs.getString(_kUserEmail);

    // ✅ communityRole: preferir string; si no, inferir desde bool compat
    final cr = (prefs.getString(_kCommunityRole) ?? '').trim();
    if (cr.isNotEmpty) {
      _cachedCommunityRole = cr;
    } else {
      final isAdminComunidad = prefs.getBool(_kIsAdminComunidadCompat) ?? false;
      _cachedCommunityRole = isAdminComunidad ? 'ADMIN' : 'USER';
      await prefs.setString(_kCommunityRole, _cachedCommunityRole!);
    }

    // Google token: si no hay internet, igual mantenemos la sesión local.
    if (_authMode == _modeGoogle && FirebaseAuth.instance.currentUser != null) {
      try {
        await attachFirebaseSession(forceRefreshToken: false);
        if ((_bearerToken ?? '').isEmpty) _bearerToken = null;
      } catch (_) {
        // offline no invalida la sesión local
      }
    } else {
      _bearerToken = null;
    }
  }

  // =========================================================
  //  APP START: ruta inicial (solo prefs, no red)
  // =========================================================
  static Future<String> computeInitialRoute() async {
    // ✅ aquí conviene restaurar siempre (no depender de _restored)
    await restoreSession();

    final prefs = await SharedPreferences.getInstance();

    final userId = prefs.getInt(_kUserId);
    if (userId == null || userId <= 0) {
      return AppRoutes.login;
    }

    // ✅ si era Google pero no hay usuario Firebase, fuerza salida local
    final mode = prefs.getString(_kAuthMode) ?? _modeLegacy;
    if (mode == _modeGoogle && FirebaseAuth.instance.currentUser == null) {
      await logout();
      return AppRoutes.login;
    }

    final communityId =
        prefs.getInt(_kCommunityId) ?? prefs.getInt(_kActiveCommunityIdCompat);
    if (communityId == null) {
      return AppRoutes.communityPicker;
    }

    return AppRoutes.home;
  }

  // =========================================================
  //  FIREBASE (Google)
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

  static Future<void> attachFirebaseSession(
      {bool forceRefreshToken = true}) async {
    final token = await getFirebaseIdToken(forceRefresh: forceRefreshToken);
    if (token == null || token.isEmpty) {
      // Importante: NO borrar sesión local. Solo bearer.
      _bearerToken = null;
      return;
    }
    _bearerToken = token;
  }

  // =========================================================
  //  PERFIL /usuarios/me (Google) - OFFLINE FRIENDLY
  // =========================================================
  static Future<Map<String, dynamic>> backendMe() async {
    await ensureRestored();

    // LEGACY: no depende de red
    if (_authMode == _modeLegacy) {
      final id = await getCurrentUserId();
      if (id == null) {
        return {'success': false, 'message': 'Sin sesión legacy'};
      }
      return {'success': true, 'message': 'Sesión legacy OK', 'userId': id};
    }

    // GOOGLE: si no hay internet, devuelve sesión local si existe
    final online = await isOnline();
    if (!online) {
      final id = await getCurrentUserId();
      if (id != null && id > 0) {
        return {
          'success': true,
          'offline': true,
          'message': 'Modo offline: usando sesión local',
          'userId': id,
        };
      }
      return {
        'success': false,
        'offline': true,
        'message': 'No hay internet y no hay sesión local'
      };
    }

    try {
      // Si hay usuario firebase y no hay bearer, intenta adjuntar sin forzar
      if (FirebaseAuth.instance.currentUser != null &&
          ((_bearerToken ?? '').isEmpty)) {
        await attachFirebaseSession(forceRefreshToken: false);
      }

      final response = await http.get(
        Uri.parse('$baseUrl/usuarios/me'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final decoded = _decodeBody(response.body);
        final usuario = _parseUsuario(decoded);
        if (usuario == null) {
          return {
            'success': false,
            'message': 'Respuesta inválida del servidor (/usuarios/me)'
          };
        }
        await _saveUserData(usuario);
        return {'success': true, 'usuario': usuario};
      }

      if (response.statusCode == 401 &&
          FirebaseAuth.instance.currentUser != null) {
        await attachFirebaseSession(forceRefreshToken: true);

        final retry = await http.get(
          Uri.parse('$baseUrl/usuarios/me'),
          headers: headers,
        );

        if (retry.statusCode == 200) {
          final decoded = _decodeBody(retry.body);
          final usuario = _parseUsuario(decoded);
          if (usuario == null) {
            return {
              'success': false,
              'message': 'Respuesta inválida del servidor (/usuarios/me)'
            };
          }
          await _saveUserData(usuario);
          return {'success': true, 'usuario': usuario};
        }

        if (retry.statusCode == 401 || retry.statusCode == 403) {
          return {
            'success': false,
            'code': retry.statusCode,
            'message': 'Sesión expirada o sin permisos. Inicia sesión nuevamente.'
          };
        }

        return {
          'success': false,
          'code': retry.statusCode,
          'message': _extractMessage(retry) ??
              'Error /usuarios/me (${retry.statusCode})'
        };
      }

      return {
        'success': false,
        'code': response.statusCode,
        'message': _extractMessage(response) ??
            'Sesión no válida o sin permisos (${response.statusCode})'
      };
    } on SocketException {
      // Error de red aunque connectivity diga online: trata como offline suave
      final id = await getCurrentUserId();
      if (id != null && id > 0) {
        return {
          'success': true,
          'offline': true,
          'message': 'Modo offline (error de red): usando sesión local',
          'userId': id,
        };
      }
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
        if (fotoUrl != null && fotoUrl.trim().isNotEmpty)
          'fotoUrl': fotoUrl.trim(),
      };

      final response = await http.post(
        Uri.parse('$baseUrl/usuarios'),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final decoded = _decodeBody(response.body);
        final usuario = _parseUsuario(decoded);
        if (usuario == null) {
          return {
            'success': false,
            'message': 'Respuesta inválida del servidor (registro)'
          };
        }

        await _saveUserData(usuario);
        if (usuario.id != null && _authMode == _modeLegacy) {
          _attachLegacySessionHeadersSync(usuario.id!);
        }

        return {
          'success': true,
          'message': 'Registro exitoso',
          'usuario': usuario
        };
      }

      if (response.statusCode == 409) {
        return {
          'success': false,
          'message': _extractMessage(response) ?? 'Ese correo ya está registrado'
        };
      }

      if (response.statusCode == 400) {
        return {
          'success': false,
          'message': _extractMessage(response) ?? 'Datos inválidos'
        };
      }

      return {
        'success': false,
        'message': _extractMessage(response) ??
            'Error registrando (${response.statusCode})'
      };
    } on SocketException {
      return {'success': false, 'message': 'No hay conexión a internet'};
    } catch (e) {
      return {'success': false, 'message': 'Error inesperado: $e'};
    }
  }

  // =========================================================
  //  LOGIN LEGACY
  // =========================================================
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      await _setAuthMode(_modeLegacy);
      _bearerToken = null;
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}

      final body = {'email': email.trim(), 'password': password};

      final response = await http.post(
        Uri.parse('$baseUrl/usuarios/login'),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final decoded = _decodeBody(response.body);
        final usuario = _parseUsuario(decoded);
        if (usuario == null) {
          return {
            'success': false,
            'message': 'Respuesta inválida del servidor (login)'
          };
        }

        await _saveUserData(usuario);
        if (usuario.id != null && _authMode == _modeLegacy) {
          _attachLegacySessionHeadersSync(usuario.id!);
        }

        return {
          'success': true,
          'message': 'Inicio de sesión exitoso',
          'usuario': usuario
        };
      }

      if (response.statusCode == 401) {
        return {
          'success': false,
          'message': _extractMessage(response) ?? 'Credenciales incorrectas'
        };
      }

      return {
        'success': false,
        'message': _extractMessage(response) ??
            'Error en login (${response.statusCode})'
      };
    } on SocketException {
      return {'success': false, 'message': 'No hay conexión a internet'};
    } catch (e) {
      return {'success': false, 'message': 'Error inesperado: $e'};
    }
  }

  // =========================================================
  //  LOGIN GOOGLE
  // =========================================================
  static Future<Map<String, dynamic>> loginWithFirebaseGoogle() async {
    try {
      await _setAuthMode(_modeGoogle);

      // Si no hay internet, no intentes login google
      final online = await isOnline();
      if (!online) {
        return {
          'success': false,
          'offline': true,
          'message': 'Sin internet: no se puede iniciar sesión con Google.'
        };
      }

      await attachFirebaseSession(forceRefreshToken: true);

      if ((_bearerToken ?? '').isEmpty) {
        return {
          'success': false,
          'message': 'No hay sesión Firebase. Inicia sesión con Google primero.'
        };
      }

      final response = await http.post(
        Uri.parse('$baseUrl/usuarios/google-login'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final decoded = _decodeBody(response.body);
        final usuario = _parseUsuario(decoded);
        if (usuario == null) {
          return {
            'success': false,
            'message': 'Respuesta inválida del servidor (google-login)'
          };
        }

        await _saveUserData(usuario);
        // ✅ google no adjunta X-User-Id
        _clearLegacySessionHeadersSync();

        return {
          'success': true,
          'registered': true,
          'message': 'Google OK y usuario registrado',
          'usuario': usuario
        };
      }

      if (response.statusCode == 409) {
        final decoded = _decodeBody(response.body);

        final email =
            (decoded is Map<String, dynamic> && decoded['email'] != null)
                ? decoded['email'].toString()
                : FirebaseAuth.instance.currentUser?.email;

        final fbUser = FirebaseAuth.instance.currentUser;

        return {
          'success': false,
          'registered': false,
          'email': email,
          'name': fbUser?.displayName,
          'picture': fbUser?.photoURL,
          'message': _extractMessage(response) ??
              'Correo verificado con Google, pero falta registro legal.',
        };
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        await attachFirebaseSession(forceRefreshToken: true);
        return {
          'success': false,
          'code': response.statusCode,
          'message': 'Token Firebase inválido o expirado'
        };
      }

      return {
        'success': false,
        'code': response.statusCode,
        'message': _extractMessage(response) ??
            'Error google-login (${response.statusCode})'
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

      final online = await isOnline();
      if (!online) {
        return {'success': false, 'offline': true, 'message': 'Sin internet'};
      }

      final body = {
        'token': token.trim(),
        if (deviceInfo != null && deviceInfo.trim().isNotEmpty)
          'deviceInfo': deviceInfo.trim(),
      };

      final response = await http.put(
        Uri.parse('$baseUrl/usuarios/$userId/fcm-token'),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final decoded = _decodeBody(response.body);
        final usuario = _parseUsuario(decoded);
        if (usuario != null) await _saveUserData(usuario);
        return {'success': true, 'usuario': usuario};
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        return {
          'success': false,
          'code': response.statusCode,
          'message': _extractMessage(response) ??
              'No autorizado (${response.statusCode})'
        };
      }

      return {
        'success': false,
        'code': response.statusCode,
        'message': _extractMessage(response) ??
            'Error actualizando FCM (${response.statusCode})'
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
      await prefs.setInt(_kUserId, usuario.id!);

      // ✅ SOLO legacy usa X-User-Id
      if (_authMode == _modeLegacy) {
        _attachLegacySessionHeadersSync(usuario.id!);
      } else {
        _clearLegacySessionHeadersSync();
      }
    }

    // communityId (si backend lo manda)
    try {
      final communityId = usuario.comunidadId;
      if (communityId != null) {
        _cachedCommunityId = communityId;
        await prefs.setInt(_kCommunityId, communityId);
        // compat
        await prefs.setInt(_kActiveCommunityIdCompat, communityId);
      } else {
        _cachedCommunityId = null;
        await prefs.remove(_kCommunityId);
        // NO borro compat para no romper tu flujo si lo manejas desde UI
      }
    } catch (_) {}

    // userRole (global)
    try {
      final role = (usuario.rol ?? 'USER').toUpperCase().trim();
      _cachedUserRole = role;
      await prefs.setString(_kUserRole, role);
    } catch (_) {}

    // email (oficial)
    try {
      final email = (usuario.email ?? '').trim();
      _cachedUserEmail = email;
      if (email.isNotEmpty) {
        await prefs.setString(_kUserEmail, email);
        // compat UI
        await prefs.setString(_kEmailUi, email);
      } else {
        await prefs.remove(_kUserEmail);
        await prefs.remove(_kEmailUi);
      }
    } catch (_) {}

    // ✅ communityRole: NO lo derives de usuario.rol (no es lo mismo).
    // Mantener el existente o inferir desde isAdminComunidad.
    try {
      final existing = (prefs.getString(_kCommunityRole) ?? '').trim();
      if (existing.isNotEmpty) {
        _cachedCommunityRole = existing;
      } else {
        final isAdminComunidad = prefs.getBool(_kIsAdminComunidadCompat) ?? false;
        _cachedCommunityRole = isAdminComunidad ? 'ADMIN' : 'USER';
        await prefs.setString(_kCommunityRole, _cachedCommunityRole!);
      }
    } catch (_) {}
  }

  static Future<int?> getCurrentUserId() async {
    if (_cachedUserId != null) return _cachedUserId;

    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_kUserId);
    if (id != null) {
      _cachedUserId = id;

      // ✅ SOLO legacy usa X-User-Id
      if (_authMode == _modeLegacy) {
        _attachLegacySessionHeadersSync(id);
      }
    }
    return id;
  }

  static Future<int?> getCurrentCommunityId() async {
    if (_cachedCommunityId != null) return _cachedCommunityId;

    final prefs = await SharedPreferences.getInstance();
    final id =
        prefs.getInt(_kCommunityId) ?? prefs.getInt(_kActiveCommunityIdCompat);
    _cachedCommunityId = id;
    return id;
  }

  static Future<String?> getCurrentUserRole() async {
    if (_cachedUserRole != null) return _cachedUserRole;

    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString(_kUserRole);
    _cachedUserRole = role;
    return role;
  }

  static Future<String?> getCurrentUserEmail() async {
    if (_cachedUserEmail != null) return _cachedUserEmail;

    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_kUserEmail);
    _cachedUserEmail = email;
    return email;
  }

  static Future<String?> getCurrentCommunityRole() async {
    if (_cachedCommunityRole != null) return _cachedCommunityRole;

    final prefs = await SharedPreferences.getInstance();

    final role = prefs.getString(_kCommunityRole);
    if (role != null && role.trim().isNotEmpty) {
      _cachedCommunityRole = role;
      return role;
    }

    // fallback: inferir por bool compat
    final isAdminComunidad = prefs.getBool(_kIsAdminComunidadCompat) ?? false;
    final inferred = isAdminComunidad ? 'ADMIN' : 'USER';
    _cachedCommunityRole = inferred;
    await prefs.setString(_kCommunityRole, inferred);
    return inferred;
  }

  // ✅ LOGOUT CORREGIDO: limpia prefs + memoria + rehidratación
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    // 1) Cierra Firebase primero (evita reenganche de token)
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    // 2) Limpia sesión oficial
    await prefs.remove(_kUserId);
    await prefs.remove(_kCommunityId);
    await prefs.remove(_kAuthMode);
    await prefs.remove(_kUserRole);
    await prefs.remove(_kUserEmail);
    await prefs.remove(_kCommunityRole);

    // 3) Limpia compat comunidad
    await prefs.remove(_kActiveCommunityIdCompat);
    await prefs.remove(_kIsAdminComunidadCompat);

    // 4) Limpia flags viejos
    await prefs.remove('isAdmin');
    await prefs.remove('isSuperAdmin');
    await prefs.remove('isCommunityAdmin');

    // 5) ✅ Limpia caches UI (causa #1 de “regresa la misma cuenta”)
    await prefs.remove(_kDisplayNameUi);
    await prefs.remove(_kPhotoUrlUi);
    await prefs.remove(_kEmailUi);
    await prefs.remove(_kComunidadNombreUi);
    await prefs.remove(_kComunidadFotoUrlUi);

    // 6) Limpia memoria
    _cachedUserId = null;
    _cachedCommunityId = null;
    _cachedUserRole = null;
    _cachedUserEmail = null;
    _cachedCommunityRole = null;

    _legacyUserId = null;
    _bearerToken = null;
    _authMode = _modeLegacy;

    // ✅ IMPORTANTÍSIMO: permitir que ensureRestored vuelva a leer prefs
    _restored = false;
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

  static Future<bool> isAdminAsync() async {
    final role = await getCurrentUserRole();
    return (role ?? '').toUpperCase() == 'ADMIN';
  }

  // =========================================================
  //  SUPERADMIN / COMMUNITY ADMIN
  // =========================================================
  static Future<bool> isSuperAdminAsync() async {
    final email = (await getCurrentUserEmail()) ?? '';
    return email.trim().toLowerCase() == superAdminEmail.toLowerCase();
  }

  // ✅ robusto: bool compat primero, luego role string
  static Future<bool> isCommunityAdminAsync() async {
    final prefs = await SharedPreferences.getInstance();

    final boolFlag = prefs.getBool(_kIsAdminComunidadCompat);
    if (boolFlag != null) return boolFlag;

    final role = ((await getCurrentCommunityRole()) ?? '').trim().toUpperCase();
    return role == 'ADMIN' || role == 'ADMIN_COMUNIDAD';
  }
}
