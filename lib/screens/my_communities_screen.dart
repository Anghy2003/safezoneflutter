import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../routes/app_routes.dart';
import '../service/community_membership_service.dart';

class MyCommunitiesScreen extends StatefulWidget {
  const MyCommunitiesScreen({super.key});

  @override
  State<MyCommunitiesScreen> createState() => _MyCommunitiesScreenState();
}

class _MyCommunitiesScreenState extends State<MyCommunitiesScreen> {
  late final CommunityMembershipService _svc;

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _items = [];

  bool get isNightMode => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _svc = CommunityMembershipService(baseUrl: ApiConfig.baseUrl);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final userId = await _svc.getUserId();
    if (userId == null) {
      setState(() {
        _loading = false;
        _error = "No se encontró sesión (userId).";
      });
      return;
    }

    final list = await _svc.myCommunities(userId);

    if (!mounted) return;

    if (list.isNotEmpty && list.first["_error"] != null) {
      final e = list.first["_error"].toString();
      setState(() {
        _loading = false;
        _error = (e == "NO_INTERNET")
            ? "Sin internet. Conéctate para cargar tus comunidades."
            : "No se pudo cargar. ($e)";
      });
      return;
    }

    setState(() {
      _items = list;
      _loading = false;
      _error = _items.isEmpty ? "Aún no estás unido a ninguna comunidad." : null;
    });
  }

  Future<void> _openCommunity(Map<String, dynamic> item) async {
    final estado = (item["estado"] ?? "").toString().toLowerCase();
    final rol = (item["rol"] ?? "").toString().toLowerCase();

    final comunidad = (item["comunidad"] is Map)
        ? Map<String, dynamic>.from(item["comunidad"])
        : null;

    final int? comunidadId = (comunidad?["id"] as num?)?.toInt();

    if (comunidadId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo abrir la comunidad (id nulo)."), backgroundColor: Colors.red),
      );
      return;
    }

    if (estado != "activo") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tu solicitud está pendiente. Espera aprobación del admin.")),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("comunidadId", comunidadId);

    final isAdmin = rol == "admin_comunidad";
    await prefs.setBool("isAdminComunidad", isAdmin);

    if (!mounted) return;

    Navigator.pushNamed(
      context,
      AppRoutes.community,
      arguments: {
        "comunidadId": comunidadId,
        "openTab": 0,
      },
    );
  }

  Future<void> _goRequestJoin() async {
    await Navigator.pushNamed(context, AppRoutes.communityPicker);
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final night = isNightMode;

    final Color bg = night ? const Color(0xFF05070A) : const Color(0xFFF3F4F6);
    final Color card = night ? const Color(0xFF0B1016) : Colors.white;
    final Color primary = night ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
    final Color secondary = night ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final Color border = night ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);
    final Color shadow = night ? Colors.black.withOpacity(0.65) : Colors.black.withOpacity(0.08);

    const accent1 = Color(0xFFFF5A5A);
    const accent2 = Color(0xFFE53935);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => AppRoutes.goBack(context),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: night ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                        shape: BoxShape.circle,
                        border: Border.all(color: border),
                      ),
                      child: Icon(Icons.arrow_back_ios_new, size: 18, color: primary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Mis comunidades",
                      style: TextStyle(color: primary, fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    onPressed: _load,
                    icon: Icon(Icons.refresh_rounded, color: secondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: night ? Colors.white : accent2))
                  : (_items.isEmpty)
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _error ?? "Aún no estás unido a ninguna comunidad.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: secondary, fontSize: 13.5, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 12),
                                _PlusCard(
                                  night: night,
                                  card: card,
                                  border: border,
                                  shadow: shadow,
                                  primary: primary,
                                  secondary: secondary,
                                  accent1: accent1,
                                  accent2: accent2,
                                  onTap: _goRequestJoin,
                                ),
                              ],
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.92,
                          ),
                          itemCount: _items.length + 1,
                          itemBuilder: (_, i) {
                            if (i == _items.length) {
                              return _PlusCard(
                                night: night,
                                card: card,
                                border: border,
                                shadow: shadow,
                                primary: primary,
                                secondary: secondary,
                                accent1: accent1,
                                accent2: accent2,
                                onTap: _goRequestJoin,
                              );
                            }
                            final item = _items[i];
                            return _MyCommunityCard(
                              night: night,
                              card: card,
                              border: border,
                              shadow: shadow,
                              primary: primary,
                              secondary: secondary,
                              accent1: accent1,
                              accent2: accent2,
                              item: item,
                              onTap: () => _openCommunity(item),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlusCard extends StatelessWidget {
  final bool night;
  final Color card, border, shadow, primary, secondary, accent1, accent2;
  final VoidCallback onTap;

  const _PlusCard({
    required this.night,
    required this.card,
    required this.border,
    required this.shadow,
    required this.primary,
    required this.secondary,
    required this.accent1,
    required this.accent2,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border),
          boxShadow: [BoxShadow(color: shadow, blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Center(
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [accent1, accent2]),
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 34),
          ),
        ),
      ),
    );
  }
}

class _MyCommunityCard extends StatelessWidget {
  final bool night;
  final Color card, border, shadow, primary, secondary, accent1, accent2;
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _MyCommunityCard({
    required this.night,
    required this.card,
    required this.border,
    required this.shadow,
    required this.primary,
    required this.secondary,
    required this.accent1,
    required this.accent2,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final estado = (item["estado"] ?? "").toString().toLowerCase();
    final rol = (item["rol"] ?? "").toString().toLowerCase();

    final comunidad = (item["comunidad"] is Map) ? Map<String, dynamic>.from(item["comunidad"]) : {};
    final nombre = (comunidad["nombre"] ?? "Comunidad").toString();
    final fotoUrl = (comunidad["fotoUrl"] ?? "").toString().trim();
    final miembros = (comunidad["miembrosCount"] ?? 0).toString();

    final bool activo = estado == "activo";
    final bool admin = rol == "admin_comunidad";

    final chipColor = activo ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    final chipText = activo ? "ACTIVO" : "PENDIENTE";

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border),
          boxShadow: [BoxShadow(color: shadow, blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(colors: [accent1.withOpacity(0.35), accent2.withOpacity(0.25)]),
                    border: Border.all(color: border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: fotoUrl.isEmpty
                        ? Icon(Icons.groups_rounded, color: night ? Colors.white : accent2, size: 24)
                        : Image.network(
                            fotoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Icon(Icons.groups_rounded, color: night ? Colors.white : accent2, size: 24),
                          ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: chipColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: chipColor.withOpacity(0.35)),
                  ),
                  child: Text(chipText, style: TextStyle(color: chipColor, fontSize: 11, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              nombre,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: primary, fontSize: 14.5, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text("$miembros miembros", style: TextStyle(color: secondary, fontSize: 12.5, fontWeight: FontWeight.w700)),
            const Spacer(),
            Row(
              children: [
                if (admin)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: (night ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: border),
                    ),
                    child: Text("ADMIN", style: TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.w900)),
                  ),
                const Spacer(),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [accent1, accent2])),
                  child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
