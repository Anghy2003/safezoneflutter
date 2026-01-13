// lib/screens/admin_reportes_screen.dart
import 'dart:convert';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../service/admin_api.dart';

class AdminReportesScreen extends StatefulWidget {
  const AdminReportesScreen({super.key});

  @override
  State<AdminReportesScreen> createState() => _AdminReportesScreenState();
}

class _AdminReportesScreenState extends State<AdminReportesScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> incidentes = [];

  // ONLINE/OFFLINE
  bool _isOnline = true;

  // Cache
  static const String _kCacheKey = "cached_admin_incidentes_v1";

  final TextEditingController _search = TextEditingController();
  String _query = "ALL"; // ALL | PENDIENTE | ATENDIDO | FALSO_POSITIVO

  late final AnimationController _fade;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();

    _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _a = CurvedAnimation(parent: _fade, curve: Curves.easeOutCubic);

    _search.addListener(() {
      if (mounted) setState(() {});
    });

    _boot();
  }

  @override
  void dispose() {
    _fade.dispose();
    _search.dispose();
    super.dispose();
  }

  // ===================== OFFLINE/ONLINE BOOT =====================

  Future<void> _boot() async {
    // 1) Cache primero (abre rápido y soporta offline)
    await _loadFromCache();

    // 2) Conectividad
    _isOnline = await _hasInternetNow();
    if (mounted) setState(() {});

    // 3) Si hay internet, refresca y guarda cache
    if (_isOnline) {
      await _loadOnlineAndCache(showSpinner: incidentes.isEmpty);
    } else {
      // Offline: si no hay cache, muestra error claro
      if (incidentes.isEmpty && mounted) {
        setState(() {
          _error = "Estás sin internet y no hay reportes guardados.\nConéctate y recarga para obtener el listado.";
          _loading = false;
        });
      }
    }
  }

  Future<bool> _hasInternetNow() async {
    final results = await Connectivity().checkConnectivity();
    return !results.contains(ConnectivityResult.none);
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
        incidentes = list;
        _loading = false;
        _error = null;
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
  }

  Future<void> _loadOnlineAndCache({required bool showSpinner}) async {
    if (!mounted) return;

    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _error = null);
    }

    try {
      final data = await AdminApi.getList("/incidentes");
      final list = data.cast<Map<String, dynamic>>();

      if (!mounted) return;
      setState(() {
        incidentes = list;
        _loading = false;
        _error = null;
      });

      _fade.forward(from: 0);
      await _saveCache(list);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        if (incidentes.isEmpty) {
          _error = e.toString();
        } else {
          _error = null; // mantenemos cache visible
        }
      });

      if (incidentes.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No se pudo refrescar. Mostrando datos guardados. ($e)")),
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

    await _loadOnlineAndCache(showSpinner: incidentes.isEmpty);
  }

  // ===================== ACCIONES =====================

  Future<void> _eliminar(dynamic id) async {
    // Eliminar requiere internet
    final online = await _hasInternetNow();
    _isOnline = online;
    if (mounted) setState(() {});

    if (!online) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Necesitas internet para eliminar un reporte."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ConfirmDialog(night: Theme.of(context).brightness == Brightness.dark),
    );

    if (ok != true) return;

    try {
      await AdminApi.delete("/incidentes/$id");
      setState(() => incidentes.removeWhere((r) => r["id"] == id));
      await _saveCache(incidentes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reporte eliminado.")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // ===================== FILTROS =====================

  String _norm(String s) => s.trim().toLowerCase();

  String _estadoKey(dynamic raw) {
    final s = (raw ?? "").toString().trim().toLowerCase();
    if (s.contains("atendido")) return "ATENDIDO";
    if (s.contains("falso")) return "FALSO_POSITIVO";
    if (s.contains("pend")) return "PENDIENTE";
    return "PENDIENTE";
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _norm(_search.text);
    return incidentes.where((r) {
      final tipo = (r["tipo"] ?? r["aiCategoria"] ?? "—").toString();
      final comu = (r["comunidadNombre"] ?? r["comunidad"] ?? "Sin comunidad").toString();
      final estado = _estadoKey(r["estado"]);

      final passEstado = _query == "ALL" ? true : estado == _query;
      final hay = q.isEmpty
          ? true
          : _norm(tipo).contains(q) || _norm(comu).contains(q) || _norm(estado).contains(q);

      return passEstado && hay;
    }).toList();
  }

  // ===================== UI =====================

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;

    final bg = night ? const Color(0xFF050509) : const Color(0xFFF7F7FB);
    final text = night ? Colors.white : const Color(0xFF15161A);
    final sub = night ? Colors.white70 : const Color(0xFF5A5E6A);

    final glass = night ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.80);
    final border = night ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06);

    final list = _filtered;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          const _AdminBackgroundFX(),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
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
                            Text("Reportes",
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: text)),
                            const SizedBox(height: 4),
                            Text("Incidentes reportados • acciones administrativas",
                                style: TextStyle(fontSize: 12.5, color: sub)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

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
                            Icon(_isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded, size: 14, color: text),
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

                // Search + filtros
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: glass,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(night ? 0.35 : 0.06),
                              blurRadius: 18,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _search,
                              style: TextStyle(color: text),
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.search_rounded, color: sub),
                                hintText: "Buscar por tipo, comunidad o estado…",
                                hintStyle: TextStyle(color: sub),
                                filled: true,
                                fillColor: night ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _FilterPill(
                                    night: night,
                                    text: "Todos",
                                    selected: _query == "ALL",
                                    onTap: () => setState(() => _query = "ALL"),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _FilterPill(
                                    night: night,
                                    text: "Pendiente",
                                    selected: _query == "PENDIENTE",
                                    onTap: () => setState(() => _query = "PENDIENTE"),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _FilterPill(
                                    night: night,
                                    text: "Atendido",
                                    selected: _query == "ATENDIDO",
                                    onTap: () => setState(() => _query = "ATENDIDO"),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _FilterPill(
                                    night: night,
                                    text: "Falso",
                                    selected: _query == "FALSO_POSITIVO",
                                    onTap: () => setState(() => _query = "FALSO_POSITIVO"),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Body
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: _ErrorCard(
                                night: night,
                                message: _error!,
                                onRetry: _onRefreshPressed,
                              ),
                            )
                          : list.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: _EmptyState(night: night),
                                )
                              : FadeTransition(
                                  opacity: _a,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: list.length,
                                    itemBuilder: (_, i) {
                                      final r = list[i];

                                      final id = r["id"];
                                      final tipo = (r["tipo"] ?? r["aiCategoria"] ?? "—").toString();
                                      final comu =
                                          (r["comunidadNombre"] ?? r["comunidad"] ?? "Sin comunidad").toString();
                                      final estado = _estadoKey(r["estado"]);

                                      final fechaIso =
                                          (r["fechaCreacion"] ?? r["fecha"] ?? r["createdAt"] ?? "").toString();
                                      final fecha = _prettyDate(fechaIso);

                                      final risk = (r["aiRiesgo"] ?? r["riesgo"] ?? "").toString();

                                      return _ReporteCard(
                                        night: night,
                                        id: id,
                                        tipo: tipo,
                                        comunidad: comu,
                                        estado: estado,
                                        fecha: fecha,
                                        riesgo: risk,
                                        onDelete: () => _eliminar(id),
                                      );
                                    },
                                  ),
                                ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _prettyDate(String iso) {
    if (iso.trim().isEmpty) return "—";
    try {
      final d = DateTime.parse(iso).toLocal();
      final dd = d.day.toString().padLeft(2, "0");
      final mm = d.month.toString().padLeft(2, "0");
      final yy = d.year.toString();
      final hh = d.hour.toString().padLeft(2, "0");
      final mi = d.minute.toString().padLeft(2, "0");
      return "$dd/$mm/$yy • $hh:$mi";
    } catch (_) {
      return iso;
    }
  }
}

/* ===================== CARDS / UI (igual a lo tuyo) ===================== */

class _ReporteCard extends StatefulWidget {
  final bool night;
  final dynamic id;
  final String tipo;
  final String comunidad;
  final String estado;
  final String fecha;
  final String riesgo;
  final VoidCallback onDelete;

  const _ReporteCard({
    required this.night,
    required this.id,
    required this.tipo,
    required this.comunidad,
    required this.estado,
    required this.fecha,
    required this.riesgo,
    required this.onDelete,
  });

  @override
  State<_ReporteCard> createState() => _ReporteCardState();
}

class _ReporteCardState extends State<_ReporteCard> {
  bool _pressed = false;

  Color _accent() {
    switch (widget.estado) {
      case "ATENDIDO":
        return const Color(0xFF00C2FF);
      case "FALSO_POSITIVO":
        return const Color(0xFFFFB020);
      default:
        return const Color(0xFFFF5A5F);
    }
  }

  String _estadoLabel() {
    switch (widget.estado) {
      case "ATENDIDO":
        return "Atendido";
      case "FALSO_POSITIVO":
        return "Falso positivo";
      default:
        return "Pendiente";
    }
  }

  IconData _icon() {
    switch (widget.estado) {
      case "ATENDIDO":
        return Icons.verified_rounded;
      case "FALSO_POSITIVO":
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final night = widget.night;

    final text = night ? Colors.white : const Color(0xFF15161A);
    final sub = night ? Colors.white70 : const Color(0xFF5A5E6A);

    final glass = night ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.86);
    final border = night ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06);

    final accent = _accent();

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        scale: _pressed ? 0.99 : 1.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: glass,
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(night ? 0.20 : 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: accent.withOpacity(night ? 0.26 : 0.18)),
                    ),
                    child: Icon(_icon(), color: accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.tipo,
                                style: TextStyle(
                                  color: text,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _Badge(
                              night: night,
                              label: _estadoLabel(),
                              accent: accent,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.comunidad,
                          style: TextStyle(color: sub, fontSize: 12.3, height: 1.1),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded, size: 16, color: sub),
                            const SizedBox(width: 6),
                            Text(widget.fecha, style: TextStyle(color: sub, fontSize: 11.8)),
                            const Spacer(),
                            if (widget.riesgo.trim().isNotEmpty) ...[
                              Icon(Icons.trending_up_rounded, size: 16, color: sub),
                              const SizedBox(width: 6),
                              Text(widget.riesgo, style: TextStyle(color: sub, fontSize: 11.8)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _DeleteButton(
                    night: night,
                    onTap: widget.onDelete,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  final bool night;
  final VoidCallback onTap;

  const _DeleteButton({required this.night, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final border = night ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06);
    final bg = night ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.70);

    return Tooltip(
      message: "Eliminar",
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
              child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final bool night;
  final String label;
  final Color accent;

  const _Badge({required this.night, required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    final text = night ? Colors.white : const Color(0xFF15161A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withOpacity(night ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withOpacity(night ? 0.26 : 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(color: text, fontSize: 11.2, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final bool night;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.night,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = night ? Colors.white : const Color(0xFF15161A);
    final border = night ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06);

    final bg = selected
        ? const Color(0xFFFF5A5F).withOpacity(night ? 0.30 : 0.18)
        : (night ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04));

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: fg,
            fontSize: 11.2,
            fontWeight: FontWeight.w900,
          ),
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: night ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.86),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: night ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06)),
          ),
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
                ),
                child: const Text("Reintentar"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool night;
  const _EmptyState({required this.night});

  @override
  Widget build(BuildContext context) {
    final text = night ? Colors.white : const Color(0xFF15161A);
    final sub = night ? Colors.white70 : const Color(0xFF5A5E6A);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: night ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.86),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: night ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              const Icon(Icons.inbox_rounded, color: Color(0xFFFF5A5F)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Sin reportes por ahora", style: TextStyle(color: text, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text("Cuando existan incidentes, aparecerán aquí.", style: TextStyle(color: sub, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final bool night;
  const _ConfirmDialog({required this.night});

  @override
  Widget build(BuildContext context) {
    final text = night ? Colors.white : const Color(0xFF15161A);
    final sub = night ? Colors.white70 : const Color(0xFF5A5E6A);

    return AlertDialog(
      backgroundColor: night ? const Color(0xFF0E1016) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text("Eliminar reporte", style: TextStyle(color: text, fontWeight: FontWeight.w900)),
      content: Text("¿Seguro que deseas eliminar este reporte?", style: TextStyle(color: sub)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text("Cancelar", style: TextStyle(color: sub)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF5A5F),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text("Eliminar"),
        ),
      ],
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
