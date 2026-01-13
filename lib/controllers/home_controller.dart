// lib/controllers/home_controller.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/usuario.dart';
import '../service/auth_service.dart';

class HomeState {
  final int? userId;
  final int? communityId;

  /// ✅ Header usuario
  final String? displayName;
  final String? email;
  final String? photoUrl;

  /// ✅ Header comunidad
  final String? communityName;

  /// ✅ Ubicación
  final String locationLabel;
  final Position? currentPosition;

  /// ✅ Roles
  final String? userRole;
  final String? communityRole;

  const HomeState({
    required this.userId,
    required this.communityId,
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.communityName,
    required this.locationLabel,
    required this.currentPosition,
    required this.userRole,
    required this.communityRole,
  });

  bool get isAdmin => (userRole ?? '').toUpperCase() == 'ADMIN';
  bool get hasSession => (userId ?? 0) > 0;

  HomeState copyWith({
    int? userId,
    int? communityId,
    String? displayName,
    String? email,
    String? photoUrl,
    String? communityName,
    String? locationLabel,
    Position? currentPosition,
    String? userRole,
    String? communityRole,
  }) {
    return HomeState(
      userId: userId ?? this.userId,
      communityId: communityId ?? this.communityId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      communityName: communityName ?? this.communityName,
      locationLabel: locationLabel ?? this.locationLabel,
      currentPosition: currentPosition ?? this.currentPosition,
      userRole: userRole ?? this.userRole,
      communityRole: communityRole ?? this.communityRole,
    );
  }

  static HomeState initial() => const HomeState(
        userId: null,
        communityId: null,
        displayName: null,
        email: null,
        photoUrl: null,
        communityName: null,
        locationLabel: 'Ubicación no disponible',
        currentPosition: null,
        userRole: null,
        communityRole: null,
      );
}

class HomeController extends ChangeNotifier {
  /// ✅ Singleton
  HomeController._();
  static final HomeController instance = HomeController._();

  HomeState _state = HomeState.initial();
  HomeState get state => _state;

  bool _disposed = false;

  // ✅ init idempotente
  Future<void>? _initFuture;
  DateTime? _lastInit;
  static const Duration _initTtl = Duration(minutes: 5);

  // ✅ detectar cambios de cuenta
  int? _lastUserId;

  // ✅ header cache owner
  static const String _kHeaderUserId = 'headerUserId';

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _setState(HomeState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  // =========================================================
  // ✅ RESET de sesión (para logout/login)
  // - Ya NO exige required param
  // - Si clearLocalCaches=true, borra prefs del header y de sesión
  // =========================================================
  Future<void> resetSession({bool clearLocalCaches = false}) async {
    _lastInit = null;
    _initFuture = null;
    _lastUserId = null;

    if (clearLocalCaches) {
      try {
        final prefs = await SharedPreferences.getInstance();

        // Header cache
        await prefs.remove(_kHeaderUserId);
        await prefs.remove('displayName');
        await prefs.remove('photoUrl');
        await prefs.remove('email');
        await prefs.remove('comunidadNombre');
        await prefs.remove('comunidadId');
        await prefs.remove('communityId'); // clave usada por AuthService
        await prefs.remove('userRole');
        await prefs.remove('communityRole');

        // Sesión/login (por si tu AuthService guarda aquí)
        await prefs.remove('userId');
        await prefs.remove('userEmail');
        await prefs.remove('isAdmin');
        await prefs.remove('isSuperAdmin');
        await prefs.remove('isCommunityAdmin');
      } catch (_) {
        // no-op
      }
    }

    _setState(HomeState.initial());
  }

  // =========================================================
  // INIT PRINCIPAL (idempotente, pero seguro con cambio de cuenta)
  // =========================================================
  Future<void> init({bool force = false}) async {
    // ✅ SIEMPRE rehidratar auth desde prefs (estado más reciente)
    try {
      await AuthService.restoreSession();
    } catch (_) {}

    final currentId = await AuthService.getCurrentUserId();

    final bool userSwitched =
        (currentId != null &&
            currentId > 0 &&
            _state.userId != null &&
            _state.userId != currentId);

    if (userSwitched) {
      force = true;
      await resetSession(); // ✅ ahora compila (ya no requiere param)
    }

    if (_initFuture != null) return _initFuture!;

    final now = DateTime.now();
    final fresh = _lastInit != null && now.difference(_lastInit!) < _initTtl;

    // ✅ Sólo aplica TTL si el userId coincide
    if (!force && fresh && _state.hasSession && _state.userId == currentId) {
      return;
    }

    _initFuture = _initInternal(force: force).whenComplete(() {
      _initFuture = null;
    });

    return _initFuture!;
  }

  Future<void> _initInternal({bool force = false}) async {
    debugPrint("HOME → init(force=$force)");

    // 1) cache rápido (pero NO cruces cuentas)
    await _hydrateHeaderFromPrefs();

    // 2) sesión/usuario/roles
    await _loadUserData();

    // 3) ubicación no bloquea UI
    unawaited(loadLocationAndSend());

    _lastInit = DateTime.now();
  }

  // =========================================================
  // CACHE: trae displayName/photo/email/communityName rápido
  // =========================================================
  Future<void> _hydrateHeaderFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // ✅ valida dueño del cache
      final cachedHeaderUserId = prefs.getInt(_kHeaderUserId);

      // lee sesión actual
      int? currentUserId;
      try {
        await AuthService.restoreSession();
        currentUserId = await AuthService.getCurrentUserId();
      } catch (_) {}

      // si el cache es de otro usuario, no lo uses
      if (currentUserId != null &&
          cachedHeaderUserId != null &&
          cachedHeaderUserId != currentUserId) {
        return;
      }

      final displayName = (prefs.getString('displayName') ?? '').trim();
      final photoUrl = (prefs.getString('photoUrl') ?? '').trim();
      final email = (prefs.getString('email') ?? '').trim();

      final communityName = (prefs.getString('comunidadNombre') ?? '').trim();

      // soporta ambas claves
      final communityId =
          prefs.getInt('communityId') ?? prefs.getInt('comunidadId');

      final userRole = (prefs.getString('userRole') ?? '').trim();
      final communityRole = (prefs.getString('communityRole') ?? '').trim();

      _setState(
        _state.copyWith(
          displayName: displayName.isNotEmpty ? displayName : _state.displayName,
          photoUrl: photoUrl.isNotEmpty ? photoUrl : _state.photoUrl,
          email: email.isNotEmpty ? email : _state.email,
          communityName:
              communityName.isNotEmpty ? communityName : _state.communityName,
          communityId: communityId ?? _state.communityId,
          userRole:
              userRole.isNotEmpty ? userRole.toUpperCase() : _state.userRole,
          communityRole: communityRole.isNotEmpty
              ? communityRole.toUpperCase()
              : _state.communityRole,
        ),
      );
    } catch (_) {
      // no-op
    }
  }

  Future<void> _persistHeaderToPrefs({
    required int userId,
    String? displayName,
    String? photoUrl,
    String? email,
    String? userRole,
    String? communityRole,
    String? communityName,
    int? communityId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // ✅ marca dueño del cache
      await prefs.setInt(_kHeaderUserId, userId);

      if ((displayName ?? '').trim().isNotEmpty) {
        await prefs.setString('displayName', displayName!.trim());
      }
      if ((photoUrl ?? '').trim().isNotEmpty) {
        await prefs.setString('photoUrl', photoUrl!.trim());
      }
      if ((email ?? '').trim().isNotEmpty) {
        await prefs.setString('email', email!.trim());
      }
      if ((userRole ?? '').trim().isNotEmpty) {
        await prefs.setString('userRole', userRole!.trim().toUpperCase());
      }
      if ((communityRole ?? '').trim().isNotEmpty) {
        await prefs.setString(
            'communityRole', communityRole!.trim().toUpperCase());
      }
      if ((communityName ?? '').trim().isNotEmpty) {
        await prefs.setString('comunidadNombre', communityName!.trim());
      }
      if ((communityId ?? 0) > 0) {
        await prefs.setInt('comunidadId', communityId!);
        // clave "oficial" que ya usa AuthService:
        await prefs.setInt('communityId', communityId);
      }
    } catch (_) {
      // no-op
    }
  }

  // =========================================================
  // SESIÓN + USUARIO + ROL (offline-safe)
  // =========================================================
  Future<void> _loadUserData() async {
    try {
      debugPrint("HOME → restoreSession()");
      await AuthService.restoreSession();

      final userId = await AuthService.getCurrentUserId();
      final communityId = await AuthService.getCurrentCommunityId();
      final userRole = (await AuthService.getCurrentUserRole()) ?? 'USER';
      final communityRole = (await AuthService.getCurrentCommunityRole()) ?? '';

      debugPrint(
        "HOME → local userId=$userId communityId=$communityId userRole=$userRole communityRole=$communityRole authMode=${AuthService.authMode}",
      );

      // ✅ Sin sesión local
      if (userId == null || userId <= 0) {
        await resetSession();
        return;
      }

      // ✅ si cambió userId desde la última vez, limpia estado inmediatamente
      if (_lastUserId != null && _lastUserId != userId) {
        _setState(HomeState.initial());
      }
      _lastUserId = userId;

      // ✅ precarga con datos locales
      _setState(
        _state.copyWith(
          userId: userId,
          communityId: communityId,
          userRole: userRole.toUpperCase(),
          communityRole: communityRole.toUpperCase(),
        ),
      );

      await _persistHeaderToPrefs(
        userId: userId,
        userRole: userRole,
        communityRole: communityRole,
        communityId: communityId,
      );

      // LEGACY: no backend /me
      if (AuthService.authMode == 'legacy') return;

      // GOOGLE: backendMe() offline-safe
      final result = await AuthService.backendMe();

      // ✅ Usuario OK
      if (result['success'] == true && result['usuario'] is Usuario) {
        final u = result['usuario'] as Usuario;

        // ✅ protección: si el backend devuelve otro id, ignora
        if (u.id != null && u.id != userId) {
          debugPrint(
              "HOME → /me devolvió otro usuario (${u.id}) != $userId. Ignorando.");
          return;
        }

        final rolFinal = (u.rol ?? userRole).toUpperCase();
        final nameFinal = (u.nombre ?? '').trim();
        final emailFinal = (u.email ?? '').trim();
        final photoFinal = (u.fotoUrl ?? '').trim();
        final communityNameFinal = (u.comunidadNombre ?? '').trim();

        _setState(
          _state.copyWith(
            userId: u.id ?? userId,
            communityId: u.comunidadId ?? communityId,
            userRole: rolFinal,
            displayName: nameFinal.isNotEmpty ? nameFinal : _state.displayName,
            email: emailFinal.isNotEmpty ? emailFinal : _state.email,
            photoUrl: photoFinal.isNotEmpty ? photoFinal : _state.photoUrl,
            communityName: communityNameFinal.isNotEmpty
                ? communityNameFinal
                : _state.communityName,
          ),
        );

        await _persistHeaderToPrefs(
          userId: u.id ?? userId,
          displayName: nameFinal,
          email: emailFinal,
          photoUrl: photoFinal,
          userRole: rolFinal,
          communityId: u.comunidadId ?? communityId,
          communityName: communityNameFinal,
        );

        return;
      }

      // ✅ OFFLINE OK: no borres estado
      if (result['success'] == true && result['offline'] == true) {
        debugPrint("HOME → OFFLINE: manteniendo sesión local sin /me");
        return;
      }

      // ✅ Network/offline error: mantener local
      final msg = (result['message'] ?? '').toString().toLowerCase();
      final code = result['code'];
      final isNetwork =
          result['offline'] == true ||
          msg.contains('no hay conexión') ||
          msg.contains('sin internet') ||
          msg.contains('socket');

      if (isNetwork) return;

      // ✅ Solo si inválida (401/403) limpiar
      if (code == 401 || code == 403) {
        await resetSession();
        return;
      }

      // otros errores: no tocar
      debugPrint("HOME → error no crítico: manteniendo estado local $result");
    } catch (e) {
      debugPrint("HOME → ERROR cargando usuario: $e");
      if (_state.hasSession) return;
      await resetSession();
    }
  }

  // =========================================================
  // UBICACIÓN
  // =========================================================
  Future<void> loadLocationAndSend() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _setState(_state.copyWith(locationLabel: 'GPS desactivado'));
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _setState(
          _state.copyWith(locationLabel: 'Permiso de ubicación no concedido'),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _setState(_state.copyWith(currentPosition: pos));

      // ✅ Solo enviar ubicación si online
      final online = await AuthService.isOnline();
      if (online) {
        await _sendLocationToBackend();
      }

      final placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final label = (p.subLocality?.isNotEmpty == true)
            ? p.subLocality!
            : (p.locality ?? 'Ubicación actual');

        _setState(_state.copyWith(locationLabel: label));
      }
    } catch (e) {
      debugPrint("HOME → ERROR ubicación: $e");
      _setState(_state.copyWith(locationLabel: 'Error obteniendo ubicación'));
    }
  }

  Future<void> _sendLocationToBackend() async {
    final uid = _state.userId;
    final pos = _state.currentPosition;
    if (uid == null || pos == null) return;

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/ubicaciones-usuario/actual')
          .replace(queryParameters: {
        'usuarioId': uid.toString(),
        'lat': pos.latitude.toString(),
        'lng': pos.longitude.toString(),
        'precision': pos.accuracy.round().toString(),
      });

      final resp = await http.post(uri, headers: AuthService.headers);

      if (resp.statusCode != 200 && resp.statusCode != 201) {
        debugPrint(
          'HOME → error enviando ubicación ${resp.statusCode}: ${resp.body}',
        );
      }
    } catch (e) {
      debugPrint('HOME → error red ubicación: $e');
    }
  }
}
