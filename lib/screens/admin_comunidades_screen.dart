// lib/screens/admin_comunidades_screen.dart
import 'dart:convert';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../service/admin_api.dart';

class AdminComunidadesScreen extends StatefulWidget {
  const AdminComunidadesScreen({super.key});

  @override
  State<AdminComunidadesScreen> createState() => _AdminComunidadesScreenState();
}

class _AdminComunidadesScreenState extends State<AdminComunidadesScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;

  // ONLINE/OFFLINE
  bool _isOnline = true;

  List<Map<String, dynamic>> comunidades = [];
  int? selectedId;

  String? ultimoCodigo;

  // Cache
  static const String _kCacheKey = "cached_admin_comunidades_v1";

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

  // ✅ FIX: ConnectivityResult puede ser enum (normal) o List (según versiones).
  Future<bool> _hasInternetNow() async {
    final r = await Connectivity().checkConnectivity();
    if (r is List) return !(r).contains(ConnectivityResult.none);
    return r != ConnectivityResult.none;
  }

  Future<void> _boot() async {
    // 1) Cache primero
    await _loadFromCache();

    // 2) Conectividad
    _isOnline = await _hasInternetNow();
    if (mounted) setState(() {});

    // 3) Si hay internet: refrescar
    if (_isOnline) {
      await _loadOnlineAndCache();
    } else {
      // si no hay cache, mostrar aviso claro
      if (comunidades.isEmpty && mounted) {
        setState(() {
          _error =
              "Estás offline y no hay comunidades guardadas.\nConéctate para cargar datos.";
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCacheKey);
      if (raw == null || raw.trim().isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final m = Map<String, dynamic>.from(decoded);
      final list = (m["comunidades"] is List) ? (m["comunidades"] as List) : const [];
      final cached = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (!mounted) return;
      setState(() {
        comunidades = cached;
        ultimoCodigo = (m["ultimoCodigo"] ?? "").toString().trim().isEmpty
            ? null
            : (m["ultimoCodigo"] ?? "").toString();
        _loading = false;
        _error = cached.isEmpty ? "No hay datos guardados aún." : null;
      });

      _fade.forward(from: 0);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      "comunidades": comunidades,
      "ultimoCodigo": ultimoCodigo,
      "cachedAt": DateTime.now().toIso8601String(),
    });
    await prefs.setString(_kCacheKey, payload);
  }

  Future<void> _loadOnlineAndCache() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await AdminApi.listarComunidades();
      if (!mounted) return;

      // ✅ Mejor: actualizar dentro de setState (evita glitches)
      setState(() {
        comunidades = data;
        _loading = false;
        _error = data.isEmpty ? "No se encontraron comunidades." : null;
      });

      _fade.forward(from: 0);
      await _saveCache();
    } catch (e) {
      if (!mounted) return;

      // si ya hay cache, no bloquees: sólo avisa
      setState(() {
        _loading = false;
        if (comunidades.isEmpty) _error = e.toString();
      });

      if (comunidades.isNotEmpty) {
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
        const SnackBar(content: Text("Estás offline. Mostrando datos guardados.")),
      );
      return;
    }

    await _loadOnlineAndCache();
  }

  List<Map<String, dynamic>> get pendientes => comunidades
      .where((c) => (c["estado"] ?? "").toString().toUpperCase() == "SOLICITADA")
      .toList();

  List<Map<String, dynamic>> get activas => comunidades
      .where((c) => (c["estado"] ?? "").toString().toUpperCase() == "ACTIVA")
      .toList();

  Future<void> _aprobar() async {
    if (selectedId == null) return;

    // Aprobar requiere internet (acción administrativa/servidor)
    final online = await _hasInternetNow();
    _isOnline = online;
    if (mounted) setState(() {});

    if (!online) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No puedes aprobar offline. Conéctate e inténtalo nuevamente."),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final updated = await AdminApi.aprobarComunidad(selectedId!);
      final code = updated["codigoAcceso"]?.toString();

      if (!mounted) return;

      setState(() {
        comunidades.removeWhere((c) => (c["id"] as num).toInt() == selectedId);
        comunidades.insert(0, updated);
        selectedId = null;
        ultimoCodigo = code;
        _loading = false;
      });

      await _saveCache();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(code != null ? "Aprobada. Código: $code" : "Aprobada. Sin código devuelto."),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error aprobando: $e")),
      );
    }
  }

  Future<void> _copyUltimoCodigo() async {
    final code = (ultimoCodigo ?? "").trim();
    if (code.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Código copiado al portapapeles.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;

    final bg = night ? const Color(0xFF050509) : const Color(0xFFF7F7FB);
    final text = night ? Colors.white : const Color(0xFF15161A);
    final sub = night ? Colors.white70 : const Color(0xFF5A5E6A);
    final border = night ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          const _AdminBackgroundFX(),
          SafeArea(
            child: FadeTransition(
              opacity: _a,
              child: RefreshIndicator(
                onRefresh: _onRefreshPressed,
                child: CustomScrollView(
                  // ✅ UX: permite pull-to-refresh aunque haya poco contenido
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
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
                                    "Comunidades",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: text,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Aprobar solicitudes y ver comunidades activas",
                                    style: TextStyle(fontSize: 12.5, color: sub),
                                  ),
                                ],
                              ),
                            ),

                            // Chip Online/Offline
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: night ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.05),
                                border: Border.all(color: border),
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
                                    style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.w800),
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

                    // Aprobar solicitada
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                        child: _GlassCard(
                          night: night,
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF5A5F).withOpacity(night ? 0.20 : 0.12),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFFFF5A5F).withOpacity(night ? 0.26 : 0.18),
                                      ),
                                    ),
                                    child: const Icon(Icons.apartment_rounded, color: Color(0xFFFF5A5F)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Aprobar comunidad solicitada",
                                          style: TextStyle(
                                            color: text,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _isOnline
                                              ? "Selecciona una SOLICITADA para generar código"
                                              : "Offline: puedes ver datos, pero no aprobar",
                                          style: TextStyle(color: sub, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              _StyledDropdown(
                                night: night,
                                value: selectedId,
                                hint: "-- Selecciona --",
                                items: pendientes
                                    .map(
                                      (c) => _DropItem(
                                        value: (c["id"] as num).toInt(),
                                        label: (c["nombre"] ?? "—").toString(),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (_loading || !_isOnline) ? null : (v) => setState(() => selectedId = v),
                              ),

                              const SizedBox(height: 10),

                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: (_loading || selectedId == null || !_isOnline) ? null : _aprobar,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF5A5F),
                                    disabledBackgroundColor: const Color(0xFFFF5A5F).withOpacity(0.45),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    elevation: 0,
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: _loading
                                        ? const SizedBox(
                                            key: ValueKey("loading"),
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Text(
                                            "Aprobar y generar código",
                                            key: ValueKey("text"),
                                            style: TextStyle(fontWeight: FontWeight.w800),
                                          ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 10),

                              _InlinePill(
                                night: night,
                                label: "Último código",
                                value: ultimoCodigo ?? "—",
                                accent: const Color(0xFFFF5A5F),
                                onTap: _copyUltimoCodigo,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Header activas
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Comunidades activas",
                                style: TextStyle(color: text, fontWeight: FontWeight.w900, fontSize: 14),
                              ),
                            ),
                            Text(
                              _loading ? "Cargando…" : "${activas.length}",
                              style: TextStyle(color: sub, fontSize: 12),
                            ),
                          ],
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
                    else if (activas.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                          child: Text("No hay comunidades activas.", style: TextStyle(color: Colors.white70)),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final c = activas[index];
                            final nombre = (c["nombre"] ?? "—").toString();
                            final codigo = (c["codigoAcceso"] ?? "—").toString();
                            final dir = (c["direccion"] ?? "—").toString();
                            final miembros = (c["miembrosCount"] ?? 0).toString();

                            return Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                              child: _GlassCard(
                                night: night,
                                padding: EdgeInsets.zero,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  title: Text(nombre, style: TextStyle(color: text, fontWeight: FontWeight.w900)),
                                  subtitle: Text(
                                    "$dir • Miembros: $miembros",
                                    style: TextStyle(color: sub, fontSize: 12),
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF5A5F).withOpacity(night ? 0.18 : 0.10),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: const Color(0xFFFF5A5F).withOpacity(night ? 0.22 : 0.14),
                                      ),
                                    ),
                                    child: Text(
                                      codigo,
                                      style: TextStyle(color: text, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: activas.length,
                        ),
                      ),

                    SliverToBoxAdapter(
                      child: SizedBox(height: MediaQuery.of(context).padding.bottom + 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ===================== UI HELPERS ===================== */

class _DropItem {
  final int value;
  final String label;
  _DropItem({required this.value, required this.label});
}

class _StyledDropdown extends StatelessWidget {
  final bool night;
  final int? value;
  final String hint;
  final List<_DropItem> items;
  final ValueChanged<int?>? onChanged;

  const _StyledDropdown({
    required this.night,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final border = night ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06);
    final fill = night ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.75);
    final text = night ? Colors.white : const Color(0xFF15161A);
    final sub = night ? Colors.white70 : const Color(0xFF5A5E6A);

    return DropdownButtonFormField<int?>(
      value: value,
      isExpanded: true,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: sub),
      items: [
        DropdownMenuItem<int?>(
          value: null,
          child: Text(hint, style: TextStyle(color: sub)),
        ),
        ...items.map(
          (i) => DropdownMenuItem<int?>(
            value: i.value,
            child: Text(i.label, style: TextStyle(color: text, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: fill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: const Color(0xFFFF5A5F).withOpacity(0.35)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}

class _InlinePill extends StatelessWidget {
  final bool night;
  final String label;
  final String value;
  final Color accent;
  final VoidCallback? onTap;

  const _InlinePill({
    required this.night,
    required this.label,
    required this.value,
    required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = night ? Colors.white : const Color(0xFF15161A);
    final sub = night ? Colors.white70 : const Color(0xFF5A5E6A);

    return InkWell(
      onTap: (value.trim().isEmpty || value == "—") ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: accent.withOpacity(night ? 0.14 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withOpacity(night ? 0.22 : 0.14)),
        ),
        child: Row(
          children: [
            Text("$label:", style: TextStyle(color: sub, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(value, style: TextStyle(color: text, fontWeight: FontWeight.w900)),
            ),
            const Icon(Icons.copy_rounded, size: 16, color: Color(0xFFFF5A5F)),
          ],
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
            child: _Blob(
              color: const Color(0xFFFF5A5F).withOpacity(night ? 0.18 : 0.14),
              size: 240,
            ),
          ),
          Positioned(
            right: -70,
            top: 90,
            child: _Blob(
              color: const Color(0xFF7C5CFF).withOpacity(night ? 0.16 : 0.12),
              size: 260,
            ),
          ),
          Positioned(
            left: 40,
            bottom: -90,
            child: _Blob(
              color: const Color(0xFF00C2FF).withOpacity(night ? 0.14 : 0.10),
              size: 280,
            ),
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
