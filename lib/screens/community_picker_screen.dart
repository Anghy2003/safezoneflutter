import 'dart:convert';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/community_card.dart';
import '../routes/app_routes.dart';
import '../service/auth_service.dart';
import '../service/community_verify_service.dart';

class CommunityPickerScreen extends StatefulWidget {
  const CommunityPickerScreen({super.key});

  @override
  State<CommunityPickerScreen> createState() => _CommunityPickerScreenState();
}

class _CommunityPickerScreenState extends State<CommunityPickerScreen> {
  final _svc = CommunityVerifyService(); // listComunidades()
  final _search = TextEditingController();

  bool _loading = true;
  String? _error;

  List<CommunityCardModel> _all = [];
  List<CommunityCardModel> _filtered = [];

  bool _isOnline = true;

  static const String _kCacheKey = "cached_communities_v1";

  bool get isNightMode => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();

    // restaurar sesión (prefs)
    AuthService.restoreSession();

    _search.addListener(() {
      _applyFilter();
      if (mounted) setState(() {});
    });

    _boot();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    await _loadFromCache();

    _isOnline = await _hasInternetNow();
    if (mounted) setState(() {});

    if (_isOnline) {
      await _loadOnlineAndCache();
    } else {
      if (_all.isEmpty && mounted) {
        setState(() {
          _error = "Sin internet y no hay datos guardados.\nConéctate para cargar comunidades.";
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
          .map((m) => CommunityCardModel.fromJson(Map<String, dynamic>.from(m)))
          .toList();

      if (!mounted) return;
      setState(() {
        _all = list;
        _filtered = list;
        _loading = false;
        _error = list.isEmpty ? "No hay comunidades guardadas aún." : null;
      });

      _applyFilter();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _saveCache(List<CommunityCardModel> list) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_kCacheKey, payload);
  }

  Future<void> _loadOnlineAndCache() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _svc.listComunidades();

      if (!mounted) return;
      setState(() {
        _all = list;
        _filtered = list;
        _loading = false;
        _error = list.isEmpty ? "No se encontraron comunidades." : null;
      });

      _applyFilter();
      await _saveCache(list);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        if (_all.isEmpty) _error = "Error cargando comunidades: $e";
      });

      if (_all.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No se pudo refrescar. Mostrando datos guardados. ($e)")),
        );
      }
    }
  }

  void _applyFilter() {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) {
      _filtered = _all;
      return;
    }
    _filtered = _all.where((c) => c.nombre.toLowerCase().contains(q)).toList();
  }

  Future<void> _openRequestJoin(CommunityCardModel c) async {
    final online = await _hasInternetNow();
    _isOnline = online;
    if (mounted) setState(() {});

    if (!online) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Necesitas internet para enviar la solicitud de unión."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      AppRoutes.requestJoinCommunity,
      arguments: {
        "communityId": c.id,
        "communityName": c.nombre,
        "communityPhotoUrl": c.fotoUrl,
      },
    );
  }

  Future<void> _openCreateCommunity() async {
    await Navigator.pushNamed(context, AppRoutes.createCommunity);

    if (!mounted) return;

    final online = await _hasInternetNow();
    _isOnline = online;
    if (mounted) setState(() {});

    if (online) {
      await _loadOnlineAndCache();
    } else {
      await _loadFromCache();
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

  @override
  Widget build(BuildContext context) {
    final night = isNightMode;

    final Color bg = night ? const Color(0xFF05070A) : const Color(0xFFFDF7F7);
    final Color card = night ? const Color(0xFF0B1016) : Colors.white;
    final Color primary = night ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
    final Color secondary = night ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final Color border = night ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);
    final Color shadow = night ? Colors.black.withOpacity(0.65) : Colors.black.withOpacity(0.08);

    const accent1 = Color(0xFFFF5A5A);
    const accent2 = Color(0xFFE53935);

    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateCommunity,
        backgroundColor: accent2,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text("Añadir comunidad", style: TextStyle(fontWeight: FontWeight.w900)),
      ),
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
                      "Selecciona tu comunidad",
                      style: TextStyle(color: primary, fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: night ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.05),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      children: [
                        Icon(_isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded, size: 14, color: primary),
                        const SizedBox(width: 6),
                        Text(
                          _isOnline ? "Online" : "Offline",
                          style: TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: _onRefreshPressed,
                    icon: Icon(Icons.refresh_rounded, color: secondary),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: border),
                      boxShadow: [BoxShadow(color: shadow, blurRadius: 14, offset: const Offset(0, 6))],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: secondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _search,
                            style: TextStyle(color: primary, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: "Buscar comunidad por nombre…",
                              hintStyle: TextStyle(color: secondary),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        if (_search.text.isNotEmpty)
                          IconButton(
                            onPressed: () {
                              _search.clear();
                              FocusScope.of(context).unfocus();
                            },
                            icon: Icon(Icons.close_rounded, color: secondary),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: night ? Colors.white : accent2))
                  : (_filtered.isEmpty)
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _error ?? "No hay resultados con ese nombre.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: secondary, fontSize: 13.5, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 12),
                                _CreateCommunityCTA(
                                  night: night,
                                  card: card,
                                  border: border,
                                  shadow: shadow,
                                  primary: primary,
                                  secondary: secondary,
                                  accent1: accent1,
                                  accent2: accent2,
                                  onTap: _openCreateCommunity,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
                          itemCount: _filtered.length + 1,
                          itemBuilder: (context, i) {
                            if (i == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _CreateCommunityCTA(
                                  night: night,
                                  card: card,
                                  border: border,
                                  shadow: shadow,
                                  primary: primary,
                                  secondary: secondary,
                                  accent1: accent1,
                                  accent2: accent2,
                                  onTap: _openCreateCommunity,
                                ),
                              );
                            }

                            final c = _filtered[i - 1];
                            return _CommunityCard(
                              night: night,
                              card: card,
                              border: border,
                              shadow: shadow,
                              primary: primary,
                              secondary: secondary,
                              accent1: accent1,
                              accent2: accent2,
                              data: c,
                              onTap: () => _openRequestJoin(c),
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

/* ===================== CTA / CARD ===================== */

class _CreateCommunityCTA extends StatelessWidget {
  final bool night;
  final Color card;
  final Color border;
  final Color shadow;
  final Color primary;
  final Color secondary;
  final Color accent1;
  final Color accent2;
  final VoidCallback onTap;

  const _CreateCommunityCTA({
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border),
          boxShadow: [BoxShadow(color: shadow, blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(colors: [accent1.withOpacity(0.35), accent2.withOpacity(0.25)]),
                border: Border.all(color: border),
              ),
              child: const Icon(Icons.add_business_rounded, color: Color(0xFFFF5A5F), size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "¿No está tu comunidad?",
                    style: TextStyle(color: primary, fontSize: 14.5, fontWeight: FontWeight.w900),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Créala o envía la solicitud para que el admin la apruebe",
                    style: TextStyle(color: secondary, fontSize: 12.3, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [accent1, accent2])),
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  final bool night;
  final Color card;
  final Color border;
  final Color shadow;
  final Color primary;
  final Color secondary;
  final Color accent1;
  final Color accent2;

  final CommunityCardModel data;
  final VoidCallback onTap;

  const _CommunityCard({
    required this.night,
    required this.card,
    required this.border,
    required this.shadow,
    required this.primary,
    required this.secondary,
    required this.accent1,
    required this.accent2,
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final photo = (data.fotoUrl ?? "").trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
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
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(colors: [accent1.withOpacity(0.35), accent2.withOpacity(0.25)]),
                  border: Border.all(color: border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: photo.isEmpty
                      ? Icon(Icons.groups_rounded, color: night ? Colors.white : accent2, size: 26)
                      : Image.network(
                          photo,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(Icons.groups_rounded, color: night ? Colors.white : accent2),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.nombre,
                      style: TextStyle(color: primary, fontSize: 14.5, fontWeight: FontWeight.w900),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Toca para solicitar unirse",
                      style: TextStyle(color: secondary, fontSize: 12.3, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [accent1, accent2])),
                child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
