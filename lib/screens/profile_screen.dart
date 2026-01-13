// lib/screens/profile_screen.dart
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:safezone_app/controllers/theme_controller.dart';
import 'package:safezone_app/service/incidente_stats_service.dart';

import '../routes/app_routes.dart';
import '../service/auth_service.dart';
import '../models/usuario.dart';

// ✅ HIVE CACHE (Perfil + stats)
import '../offline/profile_cache.dart';

// ✅ IMPORT: HomeController para resetear sesión global
import '../controllers/home_controller.dart';

// ✅ NUEVO: service de editar perfil (SIN password/foto/email)
import '../service/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  final ThemeController themeController;

  const ProfileScreen({
    super.key,
    required this.themeController,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Usuario? _usuario;
  bool _isLoading = true;

  // ✅ stats (últimos 7 días)
  int _reportCount = 0;
  List<int> _reportSeries7 = const [0, 0, 0, 0, 0, 0, 0];

  // ✅ cache
  final ProfileCache _cache = ProfileCache();
  int? _cachedUpdatedAt;

  bool get _isNightMode => Theme.of(context).brightness == Brightness.dark;

  // ✅ Acento SafeZone
  static const Color brand = Color(0xFFFE5554);

  @override
  void initState() {
    super.initState();
    _init();
  }

  // ===================== SAFE UI HELPERS =====================

  void _snackSafe(String msg) {
    if (!mounted) return;
    // ✅ Evita el crash rojo: muestra SnackBar post-frame usando el context raíz del State
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    });
  }

  Future<bool> _hasInternetNow() async {
    final r = await Connectivity().checkConnectivity();
    return r != ConnectivityResult.none;
  }

  Future<void> _init() async {
    await AuthService.restoreSession();
    if (!mounted) return;

    // 1) Cargar cache primero (Facebook-like)
    await _initCacheAndLoadSnapshot();

    // 2) Intentar refrescar online (si hay conexión)
    await _refreshOnlineIfPossible();
  }

  Future<void> _initCacheAndLoadSnapshot() async {
    try {
      await _cache.init();

      final userJson = _cache.readUser();
      final statsJson = _cache.readStats();
      final updatedAt = _cache.readUpdatedAt();

      Usuario? cachedUser;
      if (userJson != null) {
        try {
          cachedUser = Usuario.fromJson(Map<String, dynamic>.from(userJson));
        } catch (_) {
          cachedUser = null;
        }
      }

      int cachedTotal = 0;
      List<int> cachedSeries = const [0, 0, 0, 0, 0, 0, 0];
      if (statsJson != null) {
        final total = statsJson['total'];
        final last7 = statsJson['last7Days'];
        if (total is int) cachedTotal = total;
        if (last7 is List) {
          try {
            final l = last7.map((e) => (e as num).toInt()).toList();
            if (l.length == 7) cachedSeries = l;
          } catch (_) {}
        }
      }

      if (!mounted) return;

      if (cachedUser != null) {
        setState(() {
          _usuario = cachedUser;
          _reportCount = cachedTotal;
          _reportSeries7 = cachedSeries;
          _cachedUpdatedAt = updatedAt;
          _isLoading = false;
        });
        return;
      }
    } catch (_) {
      // ignora cache corrupto/no disponible
    }

    if (!mounted) return;
    setState(() {
      _cachedUpdatedAt = null;
      _isLoading = true; // sin cache: seguimos cargando esperando online
    });
  }

  Future<void> _refreshOnlineIfPossible() async {
    final online = await _hasInternetNow();
    if (!online) {
      if (!mounted) return;

      // Si NO hay cache y tampoco hay internet, dejamos pantalla con info mínima
      if (_usuario == null) {
        setState(() => _isLoading = false);
        _snackSafe("Sin internet: no se pudo cargar tu perfil.");
      }
      return;
    }

    await _loadUserAndComputeStatsOnline();
  }

  Future<void> _loadUserAndComputeStatsOnline() async {
    // 1) usuario (Google: /usuarios/me) o fallback legacy
    final me = await AuthService.backendMe();
    if (!mounted) return;

    Usuario? user;
    if (me['success'] == true && me['usuario'] is Usuario) {
      user = me['usuario'] as Usuario;
    } else {
      final id = await AuthService.getCurrentUserId();
      if (id != null) user = await _fetchUsuarioById(id);
    }

    if (!mounted) return;

    if (user == null) {
      // Si tengo cache, no tumbo la pantalla. Solo aviso.
      if (_usuario != null) {
        _snackSafe((me['message'] ?? 'No se pudo actualizar el perfil').toString());
        return;
      }

      // Sin cache y sin usuario online: sesión inválida
      setState(() {
        _usuario = null;
        _reportCount = 0;
        _reportSeries7 = const [0, 0, 0, 0, 0, 0, 0];
        _isLoading = false;
      });

      final msg = (me['message'] ?? 'Sesión no válida').toString();
      _snackSafe(msg);
      AppRoutes.navigateAndClearStack(context, AppRoutes.login);
      return;
    }

    // 2) stats desde /incidentes
    final stats = await IncidenteStatsService.fetchMyStats7Days();
    if (!mounted) return;

    setState(() {
      _usuario = user;
      _reportCount = stats.total;
      _reportSeries7 = stats.last7Days;
      _isLoading = false;
      _cachedUpdatedAt = DateTime.now().millisecondsSinceEpoch;
    });

    // 3) guardar cache
    await _saveCacheSnapshot(user: user);
  }

  Future<void> _saveCacheSnapshot({required Usuario user}) async {
    try {
      await _cache.init();
      await _cache.save(
        userJson: _usuarioToJson(user),
        total: _reportCount,
        last7Days: _reportSeries7,
      );
    } catch (_) {
      // no interrumpir UI por fallos de cache
    }
  }

  Map<String, dynamic> _usuarioToJson(Usuario u) {
    return <String, dynamic>{
      'id': u.id,
      'nombre': u.nombre,
      'apellido': u.apellido, // ✅ para edición
      'email': u.email,
      'telefono': u.telefono,
      'fotoUrl': u.fotoUrl,
      'activo': u.activo,
    };
  }

  /// ✅ Fallback legacy: GET /usuarios/{id}
  Future<Usuario?> _fetchUsuarioById(int id) async {
    try {
      final uri = Uri.parse('${AuthService.baseUrl}/usuarios/$id');
      final response = await http.get(uri, headers: AuthService.headers);

      if (response.statusCode == 200) {
        final decoded = _decodeBody(response.body);
        return _parseUsuario(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  dynamic _decodeBody(String body) {
    try {
      if (body.trim().isEmpty) return null;
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  Usuario? _parseUsuario(dynamic payload) {
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

  // ===================== EDITAR PERFIL (SOLO nombre/apellido/telefono) =====================

  bool _isValidEcuadorPhone(String v) {
    final s = v.trim();
    if (s.isEmpty) return false;

    // Formatos típicos:
    //  - 09XXXXXXXX
    //  - 0[2-7]XXXXXXX
    //  - +5939XXXXXXXX
    //  - +593[2-7]XXXXXXX
    final cleaned = s.replaceAll(RegExp(r'[^0-9+]'), '');
    final digits = cleaned.replaceAll(RegExp(r'\D'), '');

    final okLocalMobile = RegExp(r'^09\d{8}$').hasMatch(digits);
    final okLocalLand = RegExp(r'^0[2-7]\d{7}$').hasMatch(digits);
    final okE164Mobile = RegExp(r'^\+5939\d{8}$').hasMatch(cleaned);
    final okE164Land = RegExp(r'^\+593[2-7]\d{7}$').hasMatch(cleaned);

    return okLocalMobile || okLocalLand || okE164Mobile || okE164Land;
  }

  Future<void> _openEditProfileSheet() async {
    if (_usuario == null) return;

    final online = await _hasInternetNow();
    if (!online) {
      _snackSafe("Sin internet: no puedes editar el perfil ahora.");
      return;
    }

    final u = _usuario!;
    final night = _isNightMode;

    final nameCtrl = TextEditingController(text: (u.nombre ?? '').toString());
    final lastCtrl = TextEditingController(text: (u.apellido ?? '').toString());
    final phoneCtrl = TextEditingController(text: (u.telefono ?? '').toString());

    bool saving = false;

    int userId;
    try {
      userId = (u.id is int) ? (u.id as int) : int.parse(u.id.toString());
    } catch (_) {
      _snackSafe("No se pudo obtener tu ID para actualizar el perfil.");
      nameCtrl.dispose();
      lastCtrl.dispose();
      phoneCtrl.dispose();
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final surface = night ? const Color(0xFF0E1322) : Colors.white;
        final stroke = night ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06);
        final textStrong = night ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
        final textSoft = night ? const Color(0xFFA9B1C3) : const Color(0xFF64748B);

        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> doSave() async {
              if (saving) return;

              final nombre = nameCtrl.text.trim();
              final apellido = lastCtrl.text.trim();
              final telefono = phoneCtrl.text.trim();

              if (nombre.isEmpty) {
                _snackSafe("Nombre es obligatorio.");
                return;
              }
              if (apellido.isEmpty) {
                _snackSafe("Apellido es obligatorio.");
                return;
              }
              if (!_isValidEcuadorPhone(telefono)) {
                _snackSafe("Teléfono inválido (Ecuador). Ej: 09XXXXXXXX o 0[2-7]XXXXXXX o +593...");
                return;
              }

              setLocal(() => saving = true);

              try {
                // ✅ Compatible con ProfileService corregido: SOLO nombre/apellido/telefono
                final updated = await ProfileService.updateProfile(
                  id: userId,
                  nombre: nombre,
                  apellido: apellido,
                  telefono: telefono,
                );

                if (!mounted) return;

                setState(() {
                  _usuario = updated;
                  _cachedUpdatedAt = DateTime.now().millisecondsSinceEpoch;
                });

                await _saveCacheSnapshot(user: updated);

                if (!mounted) return;

                // ✅ Cierra el sheet primero (usa el context del sheet)
                Navigator.of(sheetContext).pop();

                // ✅ Evita error rojo: SnackBar post-frame en context raíz
                _snackSafe("Perfil actualizado correctamente.");
              } catch (e) {
                if (!mounted) return;

                // si el sheet sigue abierto, reactiva botón
                setLocal(() => saving = false);

                final msg = e.toString().replaceFirst('Exception: ', '');
                _snackSafe(msg);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    decoration: BoxDecoration(
                      color: surface.withOpacity(night ? 0.92 : 0.98),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                      border: Border.all(color: stroke),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "Editar perfil",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: textStrong,
                                  ),
                                ),
                              ),
                              InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: () => Navigator.of(sheetContext).pop(),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: night ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
                                    border: Border.all(color: stroke),
                                  ),
                                  child: Icon(Icons.close_rounded, size: 18, color: textStrong),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Actualiza tu información. El teléfono se valida como Ecuador; el backend normaliza a +593.",
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: textSoft),
                          ),
                          const SizedBox(height: 14),
                          _EditField(
                            night: night,
                            accent: brand,
                            label: "Nombre",
                            hint: "Ej: Andrea",
                            controller: nameCtrl,
                            icon: Icons.person_outline_rounded,
                          ),
                          const SizedBox(height: 10),
                          _EditField(
                            night: night,
                            accent: brand,
                            label: "Apellido",
                            hint: "Ej: Illescas",
                            controller: lastCtrl,
                            icon: Icons.badge_outlined,
                          ),
                          const SizedBox(height: 10),
                          _EditField(
                            night: night,
                            accent: brand,
                            label: "Teléfono",
                            hint: "09XXXXXXXX o +593...",
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            icon: Icons.phone_outlined,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: saving ? null : doSave,
                              icon: saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.save_rounded),
                              label: Text(
                                saving ? "Guardando..." : "Guardar cambios",
                                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: brand,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    lastCtrl.dispose();
    phoneCtrl.dispose();
  }

  // ===================== UI =====================

  @override
  Widget build(BuildContext context) {
    final night = _isNightMode;

    final bg = night ? const Color(0xFF070A13) : const Color(0xFFF6F7FB);
    final card = night ? const Color(0xFF0E1322) : Colors.white;
    final stroke = night ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06);
    final textStrong = night ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSoft = night ? const Color(0xFFA9B1C3) : const Color(0xFF64748B);
    final shadow = night ? Colors.black.withOpacity(0.55) : Colors.black.withOpacity(0.10);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final nombre = _usuario?.nombre ?? 'Sin nombre';
    final email = _usuario?.email ?? 'No disponible';
    final telefono = _usuario?.telefono ?? 'No disponible';
    final tipoUsuario = _usuario?.activo == false ? 'Inactivo' : 'Miembro';
    final fotoUrl = _usuario?.fotoUrl;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: night
                      ? [const Color(0xFF050712), const Color(0xFF0A0F22)]
                      : [const Color(0xFFF7F8FD), const Color(0xFFF2F4FF)],
                ),
              ),
            ),
          ),
          Positioned(
            top: -120,
            right: -90,
            child: _GlowBlob(color: brand.withOpacity(night ? 0.25 : 0.18), size: 280),
          ),
          Positioned(
            bottom: -140,
            left: -110,
            child: _GlowBlob(color: brand.withOpacity(night ? 0.18 : 0.14), size: 320),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ✅ TOP BAR
                  Row(
                    children: [
                      _IconGlassButton(
                        night: night,
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => AppRoutes.navigateAndReplace(context, AppRoutes.home),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            "Tu Perfil",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: textStrong,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 42),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _SZGlassCard(
                    night: night,
                    radius: 26,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      children: [
                        _AvatarRing(fotoUrl: fotoUrl, night: night, ringColor: brand),
                        const SizedBox(height: 12),
                        Text(
                          nombre,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textStrong),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Controla tu actividad y configura tu SafeZone",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: textSoft),
                        ),
                        if (_cachedUpdatedAt != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            "Actualizado: ${DateTime.fromMillisecondsSinceEpoch(_cachedUpdatedAt!).toLocal().toString().substring(0, 16)}",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textSoft.withOpacity(0.85)),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _QuickAction(night: night, icon: Icons.insights_rounded, label: "Actividad", onTap: () {}),
                            const SizedBox(width: 10),
                            _QuickAction(night: night, icon: Icons.security_rounded, label: "Seguridad", onTap: () {}),
                            const SizedBox(width: 10),
                            _QuickAction(night: night, icon: Icons.settings_rounded, label: "Ajustes", onTap: () {}),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  _SZCard(
                    night: night,
                    cardColor: card,
                    stroke: stroke,
                    shadow: shadow,
                    radius: 26,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _BadgeDot(night: night, color: brand),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Reportes realizados",
                                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: textStrong),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Últimos 7 días • Total: $_reportCount",
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textSoft),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: brand.withOpacity(night ? 0.18 : 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: brand.withOpacity(0.45)),
                                ),
                                child: Text(
                                  "$_reportCount",
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                    color: night ? const Color(0xFFFFD6D6) : const Color(0xFF7A1212),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _ReportsMiniChart(night: night, accent: brand, series: _reportSeries7),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ✅ DATOS + EDITAR
                  _SZCard(
                    night: night,
                    cardColor: card,
                    stroke: stroke,
                    shadow: shadow,
                    radius: 26,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _SectionTitle(
                                  night: night,
                                  title: "Datos",
                                  subtitle: "Información básica de tu cuenta",
                                ),
                              ),
                              _PillActionButton(
                                night: night,
                                accent: brand,
                                icon: Icons.edit_rounded,
                                label: "Editar",
                                onTap: _openEditProfileSheet,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _InfoRowTile(night: night, accent: brand, icon: Icons.email_outlined, label: "Email", value: email),
                          const SizedBox(height: 10),
                          _InfoRowTile(night: night, accent: brand, icon: Icons.phone_outlined, label: "Teléfono", value: telefono),
                          const SizedBox(height: 10),
                          _InfoRowTile(night: night, accent: brand, icon: Icons.badge_outlined, label: "Tipo de usuario", value: tipoUsuario),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  _SZCard(
                    night: night,
                    cardColor: card,
                    stroke: stroke,
                    shadow: shadow,
                    radius: 26,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle(night: night, title: "Preferencias", subtitle: "Cambia el modo de visualización"),
                          const SizedBox(height: 12),
                          _ThemeModeSelector(
                            night: night,
                            accent: brand,
                            value: widget.themeController.mode,
                            onChanged: (mode) async {
                              await widget.themeController.setMode(mode);
                              if (!mounted) return;
                              setState(() {});
                            },
                          ),
                          const SizedBox(height: 14),
                          Divider(color: stroke, height: 1),
                          const SizedBox(height: 14),

                          // ✅✅✅ BOTÓN CERRAR SESIÓN
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _handleLogout,
                              icon: const Icon(Icons.logout_rounded),
                              label: const Text(
                                "Cerrar sesión",
                                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: brand,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  Center(
                    child: Text(
                      "SafeZone • Perfil",
                      style: TextStyle(color: textSoft, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅✅✅ LOGOUT: además de AuthService.logout(), resetea HomeController
  void _handleLogout() {
    final night = _isNightMode;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: night ? const Color(0xFF0E1322) : Colors.white,
        title: Text(
          "Cerrar sesión",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: night ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          "¿Deseas salir de tu cuenta?",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: night ? const Color(0xFFA9B1C3) : const Color(0xFF475569),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text("Cancelar")),
          TextButton(
            onPressed: () async {
              await AuthService.logout();
              await HomeController.instance.resetSession();

              if (!mounted) return;
              Navigator.pop(dialogCtx);
              AppRoutes.navigateAndClearStack(context, AppRoutes.login);
            },
            child: Text("Salir", style: TextStyle(color: brand, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// UI COMPONENTS
// ============================================================

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      ),
    );
  }
}

class _SZCard extends StatelessWidget {
  final bool night;
  final Color cardColor;
  final Color stroke;
  final Color shadow;
  final double radius;
  final Widget child;

  const _SZCard({
    required this.night,
    required this.cardColor,
    required this.stroke,
    required this.shadow,
    required this.radius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor.withOpacity(night ? 0.96 : 1),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: stroke),
        boxShadow: [
          BoxShadow(color: shadow, blurRadius: 28, spreadRadius: 1, offset: const Offset(0, 18)),
        ],
      ),
      child: child,
    );
  }
}

class _SZGlassCard extends StatelessWidget {
  final bool night;
  final double radius;
  final EdgeInsets padding;
  final Widget child;

  const _SZGlassCard({
    required this.night,
    required this.radius,
    required this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final stroke = Colors.white.withOpacity(night ? 0.14 : 0.18);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: night
                  ? [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.03)]
                  : [Colors.white.withOpacity(0.70), Colors.white.withOpacity(0.55)],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: stroke),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _IconGlassButton extends StatelessWidget {
  final bool night;
  final IconData icon;
  final VoidCallback onTap;

  const _IconGlassButton({
    required this.night,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = night ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.04);
    final bd = night ? Colors.white.withOpacity(0.16) : Colors.black.withOpacity(0.06);
    final ic = night ? Colors.white : const Color(0xFF0F172A);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle, border: Border.all(color: bd)),
        child: Icon(icon, size: 18, color: ic),
      ),
    );
  }
}

class _AvatarRing extends StatelessWidget {
  final String? fotoUrl;
  final bool night;
  final Color ringColor;

  const _AvatarRing({
    required this.fotoUrl,
    required this.night,
    required this.ringColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: ringColor.withOpacity(night ? 0.45 : 0.28), blurRadius: 26, offset: const Offset(0, 12)),
          BoxShadow(color: Colors.black.withOpacity(night ? 0.35 : 0.10), blurRadius: 18, offset: const Offset(0, 10)),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(3.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [ringColor.withOpacity(0.90), ringColor.withOpacity(0.55), Colors.white.withOpacity(0.95)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ClipOval(
          child: (fotoUrl != null && fotoUrl!.isNotEmpty)
              ? Image.network(fotoUrl!, fit: BoxFit.cover)
              : Container(
                  color: night ? const Color(0xFF0B1020) : const Color(0xFFF1F5F9),
                  child: Icon(Icons.person_rounded, size: 54, color: night ? Colors.white70 : Colors.black54),
                ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final bool night;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.night,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = night ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.035);
    final bd = night ? Colors.white.withOpacity(0.16) : Colors.black.withOpacity(0.06);
    final ic = night ? Colors.white : const Color(0xFF0F172A);
    final tx = night ? Colors.white.withOpacity(0.85) : const Color(0xFF0F172A);

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18), border: Border.all(color: bd)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: ic),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: tx)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeDot extends StatelessWidget {
  final bool night;
  final Color color;

  const _BadgeDot({required this.night, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(night ? 0.18 : 0.12),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Icon(
        Icons.bar_chart_rounded,
        size: 18,
        color: night ? const Color(0xFFFFD6D6) : const Color(0xFF7A1212),
      ),
    );
  }
}

class _ReportsMiniChart extends StatelessWidget {
  final bool night;
  final Color accent;
  final List<int> series;

  const _ReportsMiniChart({
    required this.night,
    required this.accent,
    required this.series,
  });

  @override
  Widget build(BuildContext context) {
    final data = (series.length == 7) ? series : List<int>.filled(7, 0);
    final maxV = data.fold<int>(0, (a, b) => math.max(a, b));
    final grid = night ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);

    return Column(
      children: [
        Container(
          height: 150,
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: night ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
            border: Border.all(color: night ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.05)),
          ),
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _GridPainter(color: grid))),
              Align(
                alignment: Alignment.bottomCenter,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (i) {
                    final v = data[i];
                    final t = maxV == 0 ? 0.0 : (v / maxV);
                    final h = 12 + (t * 110);

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: h),
                          duration: const Duration(milliseconds: 650),
                          curve: Curves.easeOutCubic,
                          builder: (_, val, __) {
                            return Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                height: val,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [accent.withOpacity(0.80), accent.withOpacity(0.30)],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(7, (i) {
            const days = ["L", "M", "X", "J", "V", "S", "D"];
            return Expanded(
              child: Center(
                child: Text(
                  days[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: night ? const Color(0xFFA9B1C3) : const Color(0xFF64748B),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;

    canvas.drawLine(Offset(0, size.height * 0.25), Offset(size.width, size.height * 0.25), p);
    canvas.drawLine(Offset(0, size.height * 0.50), Offset(size.width, size.height * 0.50), p);
    canvas.drawLine(Offset(0, size.height * 0.75), Offset(size.width, size.height * 0.75), p);
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => oldDelegate.color != color;
}

class _SectionTitle extends StatelessWidget {
  final bool night;
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.night,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final t = night ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final s = night ? const Color(0xFFA9B1C3) : const Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: t)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: s)),
      ],
    );
  }
}

class _InfoRowTile extends StatelessWidget {
  final bool night;
  final Color accent;
  final IconData icon;
  final String label;
  final String value;

  const _InfoRowTile({
    required this.night,
    required this.accent,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final surface = night ? const Color(0xFF0B1020) : const Color(0xFFF8FAFC);
    final stroke = night ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.05);
    final labelC = night ? const Color(0xFFA9B1C3) : const Color(0xFF64748B);
    final valueC = night ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

    final iconBg = accent.withOpacity(night ? 0.16 : 0.10);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: stroke),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconBg,
              border: Border.all(color: accent.withOpacity(0.25)),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: labelC)),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: valueC),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  final bool night;
  final Color accent;
  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeModeSelector({
    required this.night,
    required this.accent,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final stroke = night ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06);
    final surface = night ? const Color(0xFF0B1020) : const Color(0xFFF8FAFC);
    final label = night ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final sub = night ? const Color(0xFFA9B1C3) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Tema", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: label)),
          const SizedBox(height: 4),
          Text("Selecciona modo de apariencia", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sub)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ThemeChip(
                night: night,
                accent: accent,
                selected: value == ThemeMode.system,
                icon: Icons.settings_suggest_outlined,
                title: "Sistema",
                onTap: () => onChanged(ThemeMode.system),
              ),
              _ThemeChip(
                night: night,
                accent: accent,
                selected: value == ThemeMode.light,
                icon: Icons.light_mode_outlined,
                title: "Día",
                onTap: () => onChanged(ThemeMode.light),
              ),
              _ThemeChip(
                night: night,
                accent: accent,
                selected: value == ThemeMode.dark,
                icon: Icons.dark_mode_outlined,
                title: "Noche",
                onTap: () => onChanged(ThemeMode.dark),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final bool night;
  final Color accent;
  final bool selected;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ThemeChip({
    required this.night,
    required this.accent,
    required this.selected,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? accent.withOpacity(night ? 0.22 : 0.14)
        : (night ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.03));

    final border = selected
        ? accent.withOpacity(0.75)
        : (night ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.08));

    final text = night ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final iconC = selected ? accent : (night ? Colors.white70 : Colors.black87);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: iconC),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: text)),
          ],
        ),
      ),
    );
  }
}

// ===================== EDIT WIDGETS =====================

class _PillActionButton extends StatelessWidget {
  final bool night;
  final Color accent;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PillActionButton({
    required this.night,
    required this.accent,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = night ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.03);
    final bd = night ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.08);
    final tx = night ? Colors.white.withOpacity(0.92) : const Color(0xFF0F172A);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: bd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: tx)),
          ],
        ),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final bool night;
  final Color accent;
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType keyboardType;

  const _EditField({
    required this.night,
    required this.accent,
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    final surface = night ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.03);
    final stroke = night ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.08);
    final labelC = night ? const Color(0xFFA9B1C3) : const Color(0xFF64748B);
    final textC = night ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: stroke),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withOpacity(night ? 0.16 : 0.10),
              border: Border.all(color: accent.withOpacity(0.25)),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: labelC)),
                const SizedBox(height: 6),
                TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: textC),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: hint,
                    hintStyle: TextStyle(color: labelC.withOpacity(0.9), fontWeight: FontWeight.w700),
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
