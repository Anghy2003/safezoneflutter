// lib/screens/admin_panel_screen.dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../routes/app_routes.dart';
import '../service/auth_service.dart';

import 'admin_dashboard_screen.dart';
import 'admin_comunidades_screen.dart';
import 'admin_usuarios_screen.dart';
import 'admin_reportes_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _isAdmin = false;

  // ONLINE/OFFLINE
  bool _isOnline = true;

  // Cache
  static const String _kAdminCacheKey = "cached_is_admin_v1";

  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();

    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    _slide = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);

    _boot();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<bool> _hasInternetNow() async {
    final results = await Connectivity().checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  Future<void> _saveAdminCache(bool isAdmin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAdminCacheKey, isAdmin);
  }

  Future<bool?> _readAdminCache() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAdminCacheKey);
  }

  Future<void> _boot() async {
    // (Opcional) restaurar token/sesión local primero
    AuthService.restoreSession();

    // 1) Detecta conectividad
    _isOnline = await _hasInternetNow();

    // 2) Resolver si es admin:
    //    - Online: validar con backend (fuente de verdad) y guardar cache.
    //    - Offline: usar cache (si existe). Si no hay cache, no permitir acceso.
    bool isAdmin = false;

    if (_isOnline) {
      try {
        isAdmin = await AuthService.isAdminAsync();
        await _saveAdminCache(isAdmin);
      } catch (_) {
        // si falla online, cae a cache (si existe)
        final cached = await _readAdminCache();
        isAdmin = cached == true;
      }
    } else {
      final cached = await _readAdminCache();
      isAdmin = cached == true;
    }

    if (!mounted) return;

    if (!isAdmin) {
      // No admin (o no hay cache offline): fuera del panel
      AppRoutes.navigateAndClearStack(context, AppRoutes.home);
      return;
    }

    setState(() {
      _isAdmin = true;
      _loading = false;
    });

    _anim.forward();
  }

  Future<void> _onRefreshPressed() async {
    if (_loading) return;

    final online = await _hasInternetNow();
    _isOnline = online;
    if (!mounted) return;
    setState(() {});

    if (!online) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Estás offline. Acceso admin se valida con el cache local.")),
      );
      return;
    }

    // Revalida admin con backend
    try {
      final isAdmin = await AuthService.isAdminAsync();
      await _saveAdminCache(isAdmin);

      if (!mounted) return;
      if (!isAdmin) {
        AppRoutes.navigateAndClearStack(context, AppRoutes.home);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Acceso admin revalidado.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No se pudo revalidar. ($e)")),
      );
    }
  }

  void _goHome() {
    AppRoutes.navigateAndClearStack(context, AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;

    final scaffoldBg = night ? const Color(0xFF050509) : const Color(0xFFF7F7FB);
    final cardText = night ? Colors.white : const Color(0xFF15161A);
    final subtleText = night ? Colors.white70 : const Color(0xFF5A5E6A);
    final border = night ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06);

    if (_loading) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAdmin) {
      return Scaffold(backgroundColor: scaffoldBg);
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          _BackgroundFX(night: night),

          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: Transform.translate(
                offset: Offset(0, 14 * (1 - _slide.value)),
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: _Header(
                                night: night,
                                titleColor: cardText,
                                subtitleColor: subtleText,
                                onBack: _goHome,
                              ),
                            ),
                            const SizedBox(width: 10),

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
                                      size: 14, color: cardText),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isOnline ? "Online" : "Offline",
                                    style: TextStyle(color: cardText, fontSize: 11, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 8),
                            _GlassIconButton(
                              night: night,
                              icon: Icons.refresh_rounded,
                              onTap: _onRefreshPressed,
                              tooltip: "Revalidar",
                            ),
                          ],
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                        child: _QuickStats(night: night, isOnline: _isOnline),
                      ),
                    ),

                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      sliver: SliverToBoxAdapter(
                        child: _SectionTitle(
                          night: night,
                          title: "Módulos",
                          subtitle: "Gestión y supervisión administrativa",
                        ),
                      ),
                    ),

                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                      sliver: SliverGrid(
                        delegate: SliverChildListDelegate.fixed([
                          _ModernTile(
                            night: night,
                            title: "Dashboard",
                            subtitle: "KPIs y últimas alertas",
                            icon: Icons.dashboard_outlined,
                            accent: const Color(0xFFFF5A5F),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                            ),
                          ),
                          _ModernTile(
                            night: night,
                            title: "Comunidades",
                            subtitle: "Aprobar SOLICITADA",
                            icon: Icons.apartment_outlined,
                            accent: const Color(0xFF7C5CFF),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AdminComunidadesScreen()),
                            ),
                          ),
                          _ModernTile(
                            night: night,
                            title: "Usuarios",
                            subtitle: "Estados y control",
                            icon: Icons.people_alt_outlined,
                            accent: const Color(0xFF00C2FF),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AdminUsuariosScreen()),
                            ),
                          ),
                          _ModernTile(
                            night: night,
                            title: "Reportes",
                            subtitle: "Incidentes y acciones",
                            icon: Icons.report_gmailerrorred_outlined,
                            accent: const Color(0xFFFFB020),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AdminReportesScreen()),
                            ),
                          ),
                        ]),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.05,
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: SizedBox(height: MediaQuery.of(context).padding.bottom + 18),
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

class _Header extends StatelessWidget {
  final bool night;
  final Color titleColor;
  final Color subtitleColor;
  final VoidCallback onBack;

  const _Header({
    required this.night,
    required this.titleColor,
    required this.subtitleColor,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _GlassIconButton(
          night: night,
          icon: Icons.arrow_back_rounded,
          onTap: onBack,
          tooltip: "Volver al Home",
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Panel Administrativo",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Gestión completa de SafeZone (2025 UI)",
                style: TextStyle(
                  fontSize: 12.5,
                  color: subtitleColor,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _GlassIconButton(
          night: night,
          icon: Icons.home_rounded,
          onTap: onBack,
          tooltip: "Home",
        ),
      ],
    );
  }
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
    final text = night ? Colors.white : const Color(0xFF15161A);
    final sub = night ? Colors.white70 : const Color(0xFF5A5E6A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: sub, fontSize: 12)),
      ],
    );
  }
}

class _QuickStats extends StatefulWidget {
  final bool night;
  final bool isOnline;
  const _QuickStats({required this.night, required this.isOnline});

  @override
  State<_QuickStats> createState() => _QuickStatsState();
}

class _QuickStatsState extends State<_QuickStats> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.98, end: 1.0).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final night = widget.night;
    final text = night ? Colors.white : const Color(0xFF15161A);
    final sub = night ? Colors.white70 : const Color(0xFF5A5E6A);

    return ScaleTransition(
      scale: _scale,
      child: _GlassCard(
        night: night,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _Pill(
              night: night,
              label: "Admin",
              value: widget.isOnline ? "Activo (Online)" : "Activo (Offline)",
              icon: Icons.verified_rounded,
              accent: const Color(0xFFFF5A5F),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Acceso de administrador verificado",
                      style: TextStyle(color: text, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                    widget.isOnline
                        ? "Puedes administrar comunidades, usuarios y reportes."
                        : "Estás offline: verás datos cacheados en módulos que lo soportan.",
                    style: TextStyle(color: sub, fontSize: 12, height: 1.15),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernTile extends StatefulWidget {
  final bool night;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _ModernTile({
    required this.night,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_ModernTile> createState() => _ModernTileState();
}

class _ModernTileState extends State<_ModernTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final night = widget.night;
    final text = night ? Colors.white : const Color(0xFF15161A);
    final sub = night ? Colors.white70 : const Color(0xFF5A5E6A);

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        scale: _pressed ? 0.98 : 1.0,
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
                      color: widget.accent.withOpacity(night ? 0.22 : 0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: widget.accent.withOpacity(night ? 0.22 : 0.18)),
                    ),
                    child: Icon(widget.icon, color: widget.accent, size: 22),
                  ),
                  const Spacer(),
                  Icon(Icons.north_east_rounded, color: sub),
                ],
              ),
              const SizedBox(height: 12),
              Text(widget.title, style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(widget.subtitle, style: TextStyle(color: sub, fontSize: 11.5, height: 1.15)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final bool night;
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _GlassIconButton({
    required this.night,
    required this.icon,
    required this.onTap,
    required this.tooltip,
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
    final bg = night ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.78);

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

class _Pill extends StatelessWidget {
  final bool night;
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _Pill({
    required this.night,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final text = night ? Colors.white : const Color(0xFF15161A);
    final bg = accent.withOpacity(night ? 0.18 : 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(night ? 0.22 : 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _BackgroundFX extends StatefulWidget {
  final bool night;
  const _BackgroundFX({required this.night});

  @override
  State<_BackgroundFX> createState() => _BackgroundFXState();
}

class _BackgroundFXState extends State<_BackgroundFX> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final night = widget.night;

    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value; // 0..1
        final a = (t * 2 * math.pi);

        final o1 = Offset(
          0.15 + 0.05 * (1 + math.sin(a)),
          0.10 + 0.08 * (1 + math.cos(a * 0.9)),
        );
        final o2 = Offset(
          0.70 + 0.08 * (1 + math.sin(a * 1.2)),
          0.18 + 0.06 * (1 + math.cos(a * 0.8)),
        );
        final o3 = Offset(
          0.35 + 0.10 * (1 + math.cos(a * 0.7)),
          0.78 + 0.06 * (1 + math.sin(a * 1.1)),
        );

        final base = night ? const Color(0xFF050509) : const Color(0xFFF7F7FB);

        return Container(
          color: base,
          child: Stack(
            children: [
              _blob(night, o1, const Color(0xFFFF5A5F), 260),
              _blob(night, o2, const Color(0xFF7C5CFF), 240),
              _blob(night, o3, const Color(0xFF00C2FF), 220),
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
      },
    );
  }

  Widget _blob(bool night, Offset anchor, Color color, double size) {
    return Positioned.fill(
      child: Align(
        alignment: Alignment(anchor.dx * 2 - 1, anchor.dy * 2 - 1),
        child: IgnorePointer(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(night ? 0.18 : 0.14),
            ),
          ),
        ),
      ),
    );
  }
}
