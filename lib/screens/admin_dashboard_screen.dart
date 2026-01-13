// lib/screens/admin_dashboard_screen.dart
import 'dart:convert';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../service/admin_api.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;

  // ONLINE/OFFLINE
  bool _isOnline = true;

  // KPI
  int reportesHoy = 0;
  int falsosIA = 0;
  int slaPct = 0;
  int usuariosActivos = 0;

  List<Map<String, dynamic>> ultimas = [];

  // Cache
  static const String _kCacheKey = "cached_admin_dashboard_v1";

  late final AnimationController _fade;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _a = CurvedAnimation(parent: _fade, curve: Curves.easeOutCubic);
    _boot();
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  Future<bool> _hasInternetNow() async {
    final results = await Connectivity().checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  bool _isSameDayUTC(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return false;
    final u = d.toUtc();
    final n = DateTime.now().toUtc();
    return u.year == n.year && u.month == n.month && u.day == n.day;
  }

  Future<void> _boot() async {
    // 1) Cargar cache primero (rápido y para offline)
    await _loadFromCache();

    // 2) Revisar conectividad
    _isOnline = await _hasInternetNow();
    if (mounted) setState(() {});

    // 3) Si hay internet: refrescar
    if (_isOnline) {
      await _loadOnlineAndCache();
    } else {
      // Si no hay cache, mostrar mensaje
      if (ultimas.isEmpty && mounted) {
        setState(() {
          _error = "Estás offline y no hay datos guardados del dashboard.\nConéctate para cargar KPIs.";
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

      final kpi = (m["kpi"] is Map) ? Map<String, dynamic>.from(m["kpi"]) : <String, dynamic>{};
      final last = (m["ultimas"] is List) ? (m["ultimas"] as List) : const [];

      final cachedUltimas = last
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (!mounted) return;
      setState(() {
        reportesHoy = (kpi["reportesHoy"] as num?)?.toInt() ?? 0;
        falsosIA = (kpi["falsosIA"] as num?)?.toInt() ?? 0;
        slaPct = (kpi["slaPct"] as num?)?.toInt() ?? 0;
        usuariosActivos = (kpi["usuariosActivos"] as num?)?.toInt() ?? 0;

        ultimas = cachedUltimas;
        _loading = false;
        _error = null;
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
      "kpi": {
        "reportesHoy": reportesHoy,
        "falsosIA": falsosIA,
        "slaPct": slaPct,
        "usuariosActivos": usuariosActivos,
      },
      "ultimas": ultimas,
      "cachedAt": DateTime.now().toIso8601String(),
    });
    await prefs.setString(_kCacheKey, payload);
  }

  Future<void> _loadOnlineAndCache() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final incidentesRaw = await AdminApi.getList("/incidentes");
      final usuariosRaw = await AdminApi.getList("/usuarios");

      final incidentes = incidentesRaw.cast<Map<String, dynamic>>();
      final usuarios = usuariosRaw.cast<Map<String, dynamic>>();

      reportesHoy = incidentes
          .where((i) => _isSameDayUTC((i["fechaCreacion"] ?? "").toString()))
          .length;

      falsosIA = incidentes.where((i) => i["aiPosibleFalso"] == true).length;

      usuariosActivos = usuarios.where((u) => u["activo"] != false).length;

      final total = incidentes.isEmpty ? 1 : incidentes.length;
      final resueltos = incidentes.where((i) {
        final estado = (i["estado"] ?? "").toString().toLowerCase().trim();
        final fechaResolucion = i["fechaResolucion"];
        return estado == "resuelto" || estado == "atendido" || fechaResolucion != null;
      }).length;

      slaPct = ((resueltos / total) * 100).round();

      incidentes.sort((a, b) {
        final fa = DateTime.tryParse((a["fechaCreacion"] ?? "").toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final fb = DateTime.tryParse((b["fechaCreacion"] ?? "").toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return fb.compareTo(fa);
      });

      ultimas = incidentes.take(8).toList();

      if (!mounted) return;
      setState(() => _loading = false);
      _fade.forward(from: 0);

      await _saveCache();
    } catch (e) {
      if (!mounted) return;

      // Si falla online pero hay cache, no tumbes la pantalla
      setState(() {
        _loading = false;
        if (ultimas.isEmpty) {
          _error = "Error cargando dashboard: $e";
        } else {
          _error = null;
        }
      });

      if (ultimas.isNotEmpty) {
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
    await _loadOnlineAndCache();
  }

  String _prettyDate(String iso) {
    if (iso.trim().isEmpty) return "—";
    try {
      final d = DateTime.parse(iso).toLocal();
      String p2(int n) => n.toString().padLeft(2, "0");
      return "${p2(d.day)}/${p2(d.month)}/${d.year} • ${p2(d.hour)}:${p2(d.minute)}";
    } catch (_) {
      return iso;
    }
  }

  String _estadoKey(dynamic raw) {
    final s = (raw ?? "").toString().trim().toLowerCase();
    if (s.contains("resuelto") || s.contains("atendido")) return "ATENDIDO";
    if (s.contains("falso")) return "FALSO_POSITIVO";
    if (s.contains("pend")) return "PENDIENTE";
    return "PENDIENTE";
  }

  Color _accentForEstado(String k) {
    switch (k) {
      case "ATENDIDO":
        return const Color(0xFF00C2FF);
      case "FALSO_POSITIVO":
        return const Color(0xFFFFB020);
      default:
        return const Color(0xFFFF5A5F);
    }
  }

  String _labelEstado(String k) {
    switch (k) {
      case "ATENDIDO":
        return "Atendido";
      case "FALSO_POSITIVO":
        return "Falso positivo";
      default:
        return "Pendiente";
    }
  }

  double _pct(int v) => (v.clamp(0, 100)) / 100.0;

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
            child: RefreshIndicator(
              onRefresh: _onRefreshPressed,
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
                                    "Dashboard Admin",
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: text),
                                  ),
                                  const SizedBox(height: 4),
                                  Text("KPIs + últimas alertas (móvil)", style: TextStyle(fontSize: 12.5, color: sub)),
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
                                  Icon(_isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                                      size: 14, color: text),
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

                    // HERO KPI
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                        child: _HeroSlaCard(
                          night: night,
                          titleColor: text,
                          subColor: sub,
                          slaPct: _loading ? null : slaPct,
                          activeUsers: _loading ? null : usuariosActivos,
                        ),
                      ),
                    ),

                    // KPIs grid
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      sliver: SliverGrid(
                        delegate: SliverChildListDelegate.fixed([
                          _KpiTile(
                            night: night,
                            label: "Reportes hoy",
                            value: _loading ? "…" : "$reportesHoy",
                            icon: Icons.notifications_active_rounded,
                            accent: const Color(0xFFFF5A5F),
                          ),
                          _KpiTile(
                            night: night,
                            label: "Falsos IA",
                            value: _loading ? "…" : "$falsosIA",
                            icon: Icons.warning_amber_rounded,
                            accent: const Color(0xFFFFB020),
                          ),
                          _KpiTile(
                            night: night,
                            label: "SLA",
                            value: _loading ? "…" : "$slaPct%",
                            icon: Icons.verified_rounded,
                            accent: const Color(0xFF00C2FF),
                            showProgress: !_loading,
                            progress: _pct(slaPct),
                          ),
                          _KpiTile(
                            night: night,
                            label: "Usuarios activos",
                            value: _loading ? "…" : "$usuariosActivos",
                            icon: Icons.people_alt_rounded,
                            accent: const Color(0xFF7C5CFF),
                          ),
                        ]),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.12,
                        ),
                      ),
                    ),

                    // Últimas alertas
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text("Últimas alertas",
                                  style: TextStyle(color: text, fontWeight: FontWeight.w900, fontSize: 14)),
                            ),
                            Text(
                              _loading ? "Cargando…" : (_isOnline ? "Actualizado" : "Cache"),
                              style: TextStyle(color: sub, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                        child: _GlassCard(
                          night: night,
                          padding: EdgeInsets.zero,
                          child: _loading
                              ? const Padding(
                                  padding: EdgeInsets.all(18),
                                  child: Center(child: CircularProgressIndicator()),
                                )
                              : (ultimas.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(18),
                                      child: Text("No hay alertas recientes.", style: TextStyle(color: sub)),
                                    )
                                  : Column(
                                      children: [
                                        for (final i in ultimas) ...[
                                          _UltimaRow(
                                            night: night,
                                            tipo: (i["tipo"] ?? i["aiCategoria"] ?? "—").toString(),
                                            comunidad: (i["comunidadNombre"] ?? i["comunidad"] ?? "Sin comunidad").toString(),
                                            estado: _estadoKey(i["estado"]),
                                            estadoLabel: _labelEstado(_estadoKey(i["estado"])),
                                            accent: _accentForEstado(_estadoKey(i["estado"])),
                                            fecha: _prettyDate((i["fechaCreacion"] ?? "").toString()),
                                          ),
                                          if (i != ultimas.last)
                                            Divider(
                                              height: 1,
                                              thickness: 1,
                                              color: night
                                                  ? Colors.white.withOpacity(0.08)
                                                  : Colors.black.withOpacity(0.05),
                                            ),
                                        ],
                                      ],
                                    )),
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
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

/* ===================== UI COMPONENTS ===================== */

class _HeroSlaCard extends StatelessWidget {
  final bool night;
  final Color titleColor;
  final Color subColor;
  final int? slaPct;
  final int? activeUsers;

  const _HeroSlaCard({
    required this.night,
    required this.titleColor,
    required this.subColor,
    required this.slaPct,
    required this.activeUsers,
  });

  @override
  Widget build(BuildContext context) {
    final value = slaPct == null ? "…" : "$slaPct%";
    final users = activeUsers == null ? "…" : "$activeUsers";

    return _GlassCard(
      night: night,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFFF5A5F).withOpacity(night ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFF5A5F).withOpacity(night ? 0.26 : 0.18)),
            ),
            child: const Icon(Icons.insights_rounded, color: Color(0xFFFF5A5F)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Salud operativa",
                    style: TextStyle(color: titleColor, fontWeight: FontWeight.w900, fontSize: 14)),
                const SizedBox(height: 4),
                Text("SLA global y usuarios activos del sistema", style: TextStyle(color: subColor, fontSize: 12)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _MiniStat(
                      night: night,
                      label: "SLA",
                      value: value,
                      accent: const Color(0xFF00C2FF),
                      icon: Icons.verified_rounded,
                    ),
                    const SizedBox(width: 10),
                    _MiniStat(
                      night: night,
                      label: "Activos",
                      value: users,
                      accent: const Color(0xFF7C5CFF),
                      icon: Icons.people_alt_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final bool night;
  final String label;
  final String value;
  final Color accent;
  final IconData icon;

  const _MiniStat({
    required this.night,
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final text = night ? Colors.white : const Color(0xFF15161A);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: accent.withOpacity(night ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withOpacity(night ? 0.24 : 0.16)),
        ),
        child: Row(
          children: [
            Icon(icon, color: accent, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(value, style: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final bool night;
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  final bool showProgress;
  final double progress;

  const _KpiTile({
    required this.night,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.showProgress = false,
    this.progress = 0,
  });

  @override
  Widget build(BuildContext context) {
    final text = night ? Colors.white : const Color(0xFF15161A);
    final sub = night ? Colors.white70 : const Color(0xFF5A5E6A);

    return _GlassCard(
      night: night,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withOpacity(night ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withOpacity(night ? 0.24 : 0.16)),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const Spacer(),
              Icon(Icons.north_east_rounded, color: sub, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(color: sub, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: text, fontSize: 22, fontWeight: FontWeight.w900)),
          if (showProgress) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: night ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UltimaRow extends StatelessWidget {
  final bool night;
  final String tipo;
  final String comunidad;
  final String estado;
  final String estadoLabel;
  final Color accent;
  final String fecha;

  const _UltimaRow({
    required this.night,
    required this.tipo,
    required this.comunidad,
    required this.estado,
    required this.estadoLabel,
    required this.accent,
    required this.fecha,
  });

  @override
  Widget build(BuildContext context) {
    final text = night ? Colors.white : const Color(0xFF15161A);
    final sub = night ? Colors.white70 : const Color(0xFF5A5E6A);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withOpacity(night ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withOpacity(night ? 0.24 : 0.16)),
            ),
            child: Icon(
              estado == "ATENDIDO"
                  ? Icons.verified_rounded
                  : (estado == "FALSO_POSITIVO" ? Icons.warning_amber_rounded : Icons.notifications_active_rounded),
              color: accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tipo, style: TextStyle(color: text, fontWeight: FontWeight.w900, fontSize: 13.5)),
                const SizedBox(height: 4),
                Text("$comunidad • $estadoLabel", style: TextStyle(color: sub, fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 15, color: sub),
                    const SizedBox(width: 6),
                    Text(fecha, style: TextStyle(color: sub, fontSize: 11.5)),
                  ],
                ),
              ],
            ),
          ),
        ],
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
