// lib/screens/admin_usuarios_screen.dart
import 'dart:convert';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../service/admin_api.dart';

class AdminUsuariosScreen extends StatefulWidget {
  const AdminUsuariosScreen({super.key});

  @override
  State<AdminUsuariosScreen> createState() => _AdminUsuariosScreenState();
}

class _AdminUsuariosScreenState extends State<AdminUsuariosScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> usuarios = [];

  // ONLINE/OFFLINE
  bool _isOnline = true;

  // Cache
  static const String _kCacheKey = "cached_admin_users_v1";
  static const String _kCacheUpdatedAtKey = "cached_admin_users_updated_at";

  late final AnimationController _fade;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _a = CurvedAnimation(parent: _fade, curve: Curves.easeOutCubic);

    _boot();
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  // ===================== OFFLINE/ONLINE BOOT =====================

  Future<void> _boot() async {
    // 1) Cargar cache primero (abre rápido y soporta offline)
    await _loadFromCache();

    // 2) Detectar conectividad
    _isOnline = await _hasInternetNow();
    if (mounted) setState(() {});

    // 3) Si hay internet, refrescar y cachear
    if (_isOnline) {
      await _loadOnlineAndCache(showSpinner: usuarios.isEmpty);
    } else {
      // Offline: si no hay cache, mostrar error claro
      if (usuarios.isEmpty && mounted) {
        setState(() {
          _error =
              "Estás sin internet y no hay datos guardados.\nConéctate y recarga para obtener el listado.";
          _loading = false;
        });
      }
    }
  }

  Future<bool> _hasInternetNow() async {
    final results = await Connectivity().checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  // ===================== CACHE =====================

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCacheKey);

      if (raw == null || raw.trim().isEmpty) {
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final list = decoded
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();

      if (!mounted) return;
      setState(() {
        usuarios = list;
        _loading = false;
        _error = null; // cache es válido, no muestres error
      });

      _fade.forward(from: 0);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _saveCache(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCacheKey, jsonEncode(list));
    await prefs.setInt(_kCacheUpdatedAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  String _cacheUpdatedLabel() {
    // Pequeño helper “hace X min”
    // Si no hay timestamp, no muestra nada.
    // (No uses intl para mantenerlo simple)
    // ignore: unnecessary_null_comparison
    return ""; // placeholder (lo seteo en build leyendo prefs en FutureBuilder)
  }

  // ===================== ONLINE LOAD =====================

  Future<void> _loadOnlineAndCache({required bool showSpinner}) async {
    if (!mounted) return;

    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      // sin spinner, pero limpiamos error
      setState(() => _error = null);
    }

    try {
      final data = await AdminApi.getList("/usuarios");
      final list = data.cast<Map<String, dynamic>>();

      if (!mounted) return;

      setState(() {
        usuarios = list;
        _loading = false;
        _error = list.isEmpty ? "No hay usuarios." : null;
      });

      _fade.forward(from: 0);
      await _saveCache(list);
    } catch (e) {
      if (!mounted) return;

      // Si falla online pero ya hay cache, no tumbes la pantalla
      setState(() {
        _loading = false;
        if (usuarios.isEmpty) {
          _error = e.toString();
        } else {
          _error = null;
        }
      });

      if (usuarios.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("No se pudo refrescar. Mostrando datos guardados. ($e)"),
          ),
        );
      }
    }
  }

  Future<void> _onRefreshPressed() async {
    final online = await _hasInternetNow();
    _isOnline = online;
    if (mounted) setState(() {});

    if (!online) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Estás offline. Mostrando datos guardados."),
        ),
      );
      return;
    }

    await _loadOnlineAndCache(showSpinner: usuarios.isEmpty);
  }

  // ===================== UI =====================

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;

    final bg = night ? const Color(0xFF050509) : const Color(0xFFF7F7FB);
    final text = night ? Colors.white : const Color(0xFF15161A);
    final sub = night ? Colors.white70 : const Color(0xFF5A5E6A);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          const _AdminBackgroundFX(),
          SafeArea(
            child: FadeTransition(
              opacity: _a,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                      child: Row(
                        children: [
                          _GlassIconButton(
                            night: night,
                            icon: Icons.arrow_back_rounded,
                            tooltip: "Volver",
                            onTap: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Usuarios",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: text,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Listado de usuarios y estado (activo/inactivo)",
                                  style: TextStyle(fontSize: 12.5, color: sub),
                                ),
                              ],
                            ),
                          ),

                          // ✅ Chip Online/Offline
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: night
                                  ? Colors.white.withOpacity(0.07)
                                  : Colors.black.withOpacity(0.05),
                              border: Border.all(
                                color: night
                                    ? Colors.white.withOpacity(0.10)
                                    : Colors.black.withOpacity(0.06),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                                  size: 14,
                                  color: text,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isOnline ? "Online" : "Offline",
                                  style: TextStyle(
                                    color: text,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),
                          _GlassIconButton(
                            night: night,
                            icon: Icons.refresh_rounded,
                            tooltip: "Recargar",
                            onTap: _loading ? () {} : _onRefreshPressed,
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_error != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _ErrorCard(
                          night: night,
                          message: _error!,
                          onRetry: _onRefreshPressed,
                        ),
                      ),
                    ),

                  if (_loading)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  else if (usuarios.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                        child: Text("No hay usuarios.", style: TextStyle(color: sub)),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final u = usuarios[index];

                          final nombre = ("${u["nombre"] ?? ""} ${u["apellido"] ?? ""}").trim();
                          final email = (u["email"] ?? "—").toString();
                          final activo = u["activo"] != false;
                          final comu = (u["comunidadNombre"] ?? "Sin comunidad").toString();
                          final rol = (u["rol"] ?? "—").toString();

                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                            child: _GlassCard(
                              night: night,
                              padding: EdgeInsets.zero,
                              child: ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                leading: _AvatarPill(
                                  night: night,
                                  name: nombre.isEmpty ? "?" : nombre,
                                ),
                                title: Text(
                                  nombre.isEmpty ? "Sin nombre" : nombre,
                                  style: TextStyle(color: text, fontWeight: FontWeight.w900),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    "$email • $comu • $rol",
                                    style: TextStyle(color: sub, fontSize: 12),
                                  ),
                                ),
                                trailing: _StatusChip(
                                  night: night,
                                  active: activo,
                                  textColor: text,
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: usuarios.length,
                      ),
                    ),

                  SliverToBoxAdapter(
                    child: SizedBox(height: MediaQuery.of(context).padding.bottom + 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ===================== UI HELPERS (sin cambios funcionales) ===================== */

class _StatusChip extends StatelessWidget {
  final bool night;
  final bool active;
  final Color textColor;

  const _StatusChip({
    required this.night,
    required this.active,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = active ? Colors.green : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: c.withOpacity(night ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(night ? 0.26 : 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            active ? "Activo" : "Inactivo",
            style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AvatarPill extends StatelessWidget {
  final bool night;
  final String name;

  const _AvatarPill({required this.night, required this.name});

  String _initials(String s) {
    final parts =
        s.trim().split(RegExp(r"\s+")).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return "?";
    final a = parts[0].isNotEmpty ? parts[0][0].toUpperCase() : "?";
    final b = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0].toUpperCase() : "";
    return (a + b).trim();
  }

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    final bg = const Color(0xFF7C5CFF).withOpacity(night ? 0.22 : 0.14);
    final border = const Color(0xFF7C5CFF).withOpacity(night ? 0.26 : 0.18);

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: night ? Colors.white : const Color(0xFF15161A),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final bool night;
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({
    required this.night,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final text = night ? Colors.white : const Color(0xFF15161A);
    final sub = night ? Colors.white70 : const Color(0xFF5A5E6A);

    return _GlassCard(
      night: night,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Ocurrió un error", style: TextStyle(color: text, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(message, style: TextStyle(color: sub, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5A5F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text("Reintentar"),
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final bool night;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _GlassIconButton({
    required this.night,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = night ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06);
    final bg = night ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.70);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Icon(icon, size: 22, color: night ? Colors.white : const Color(0xFF15161A)),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final bool night;
  final Widget child;
  final EdgeInsets padding;

  const _GlassCard({
    required this.night,
    required this.child,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final border = night ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06);
    final bg = night ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.82);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(night ? 0.35 : 0.06),
                blurRadius: 18,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AdminBackgroundFX extends StatelessWidget {
  const _AdminBackgroundFX();

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    final base = night ? const Color(0xFF050509) : const Color(0xFFF7F7FB);

    return Container(
      color: base,
      child: Stack(
        children: [
          Positioned(
            left: -60,
            top: -40,
            child: _Blob(color: const Color(0xFFFF5A5F).withOpacity(night ? 0.18 : 0.14), size: 240),
          ),
          Positioned(
            right: -70,
            top: 90,
            child: _Blob(color: const Color(0xFF7C5CFF).withOpacity(night ? 0.16 : 0.12), size: 260),
          ),
          Positioned(
            left: 40,
            bottom: -90,
            child: _Blob(color: const Color(0xFF00C2FF).withOpacity(night ? 0.14 : 0.10), size: 280),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.2,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(night ? 0.55 : 0.12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;

  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
