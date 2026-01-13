import 'dart:ui';
import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../routes/app_routes.dart';
import '../service/community_admin_requests_service.dart';

class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  late final CommunityAdminRequestsService _svc;

  bool _loading = true;
  String? _error;

  int? _adminId;
  int? _comunidadId;

  List<Map<String, dynamic>> _items = [];
  final Set<int> _busyUserIds = {};

  bool get isNightMode => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _svc = CommunityAdminRequestsService(baseUrl: ApiConfig.baseUrl);
    _boot();
  }

  Future<void> _boot() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final isAdmin = await _svc.isAdminCommunity();
    if (!isAdmin) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "No tienes permisos para ver esta pantalla.";
      });
      return;
    }

    final adminId = await _svc.getUserId();
    final comunidadId = await _svc.getCommunityId();

    if (!mounted) return;

    if (adminId == null) {
      setState(() {
        _loading = false;
        _error = "No se encontró sesión (userId).";
      });
      return;
    }
    if (comunidadId == null) {
      setState(() {
        _loading = false;
        _error = "No se encontró comunidad seleccionada (comunidadId).";
      });
      return;
    }

    _adminId = adminId;
    _comunidadId = comunidadId;

    await _load();
  }

  Future<void> _load() async {
    final adminId = _adminId;
    final comunidadId = _comunidadId;
    if (adminId == null || comunidadId == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final list = await _svc.listPendingRequests(
      adminId: adminId,
      comunidadId: comunidadId,
    );

    if (!mounted) return;

    if (list.isNotEmpty && list.first["_error"] != null) {
      final e = list.first["_error"].toString();
      setState(() {
        _loading = false;
        _error = (e == "NO_INTERNET")
            ? "Sin internet. Conéctate para ver solicitudes."
            : "No se pudo cargar solicitudes. ($e)";
      });
      return;
    }

    final filtered = list.where((m) {
      final estado = (m["estado"] ?? "").toString().toLowerCase();
      return estado == "pendiente";
    }).toList();

    setState(() {
      _items = filtered;
      _loading = false;
      _error = _items.isEmpty ? "No hay solicitudes pendientes." : null;
    });
  }

  int? _userId(Map<String, dynamic> item) {
    final raw = item["usuarioId"];
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  String _fullName(Map<String, dynamic> item) {
    final n = (item["nombre"] ?? "").toString().trim();
    final a = (item["apellido"] ?? "").toString().trim();
    final full = [n, a].where((x) => x.isNotEmpty).join(" ");
    return full.isNotEmpty ? full : "Usuario";
  }

  String _email(Map<String, dynamic> item) => (item["email"] ?? "").toString().trim();
  String _telefono(Map<String, dynamic> item) => (item["telefono"] ?? "").toString().trim();
  String _fotoUrl(Map<String, dynamic> item) => (item["fotoUrl"] ?? "").toString().trim();
  String _fechaUnion(Map<String, dynamic> item) => (item["fechaUnion"] ?? "").toString().trim();

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : const Color(0xFF10B981),
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  Future<void> _approve(Map<String, dynamic> item) async {
    final adminId = _adminId;
    final comunidadId = _comunidadId;
    final userId = _userId(item);

    if (adminId == null || comunidadId == null || userId == null) {
      _snack("No se pudo identificar la solicitud.", isError: true);
      return;
    }

    setState(() => _busyUserIds.add(userId));

    final resp = await _svc.approve(
      adminId: adminId,
      comunidadId: comunidadId,
      usuarioId: userId,
    );

    if (!mounted) return;
    setState(() => _busyUserIds.remove(userId));

    if (resp == null || resp["_error"] != null) {
      final e = resp?["_error"]?.toString() ?? "UNKNOWN";
      _snack(
        e == "NO_INTERNET" ? "Sin internet. No se pudo aprobar." : "No se pudo aprobar. ($e)",
        isError: true,
      );
      return;
    }

    setState(() {
      _items.removeWhere((x) => _userId(x) == userId);
      _error = _items.isEmpty ? "No hay solicitudes pendientes." : null;
    });

    _snack("Solicitud aprobada. El usuario ya está ACTIVO.");
  }

  Future<void> _reject(Map<String, dynamic> item) async {
    final adminId = _adminId;
    final comunidadId = _comunidadId;
    final userId = _userId(item);

    if (adminId == null || comunidadId == null || userId == null) {
      _snack("No se pudo identificar la solicitud.", isError: true);
      return;
    }

    final ok = await _confirm(
      title: "Rechazar solicitud",
      message: "¿Seguro que deseas rechazar esta solicitud?\n\nEl usuario quedará rechazado/expulsado.",
      confirmText: "Rechazar",
    );
    if (!ok) return;

    setState(() => _busyUserIds.add(userId));

    final resp = await _svc.reject(
      adminId: adminId,
      comunidadId: comunidadId,
      usuarioId: userId,
    );

    if (!mounted) return;
    setState(() => _busyUserIds.remove(userId));

    if (resp == null || resp["_error"] != null) {
      final e = resp?["_error"]?.toString() ?? "UNKNOWN";
      _snack(
        e == "NO_INTERNET" ? "Sin internet. No se pudo rechazar." : "No se pudo rechazar. ($e)",
        isError: true,
      );
      return;
    }

    setState(() {
      _items.removeWhere((x) => _userId(x) == userId);
      _error = _items.isEmpty ? "No hay solicitudes pendientes." : null;
    });

    _snack("Solicitud rechazada.");
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
                      "Solicitudes pendientes",
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
                            child: Text(
                              _error ?? "No hay solicitudes pendientes.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: secondary, fontSize: 13.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                          itemCount: _items.length,
                          itemBuilder: (_, i) {
                            final item = _items[i];

                            final userId = _userId(item);
                            final busy = userId != null && _busyUserIds.contains(userId);

                            final name = _fullName(item);
                            final email = _email(item);
                            final phone = _telefono(item);
                            final photo = _fotoUrl(item);
                            final fecha = _fechaUnion(item);

                            return _RequestCard(
                              night: night,
                              card: card,
                              border: border,
                              shadow: shadow,
                              primary: primary,
                              secondary: secondary,
                              accent1: accent1,
                              accent2: accent2,
                              busy: busy,
                              name: name,
                              email: email,
                              phone: phone,
                              photoUrl: photo,
                              fechaUnion: fecha,
                              onApprove: busy ? null : () => _approve(item),
                              onReject: busy ? null : () => _reject(item),
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

class _RequestCard extends StatelessWidget {
  final bool night;
  final Color card, border, shadow, primary, secondary, accent1, accent2;

  final bool busy;
  final String name;
  final String email;
  final String phone;
  final String photoUrl;
  final String fechaUnion;

  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _RequestCard({
    required this.night,
    required this.card,
    required this.border,
    required this.shadow,
    required this.primary,
    required this.secondary,
    required this.accent1,
    required this.accent2,
    required this.busy,
    required this.name,
    required this.email,
    required this.phone,
    required this.photoUrl,
    required this.fechaUnion,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final hasEmail = email.trim().isNotEmpty;
    final hasPhone = phone.trim().isNotEmpty;
    final hasFecha = fechaUnion.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(14),
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
                        child: photoUrl.isEmpty
                            ? Icon(Icons.person_rounded, color: night ? Colors.white : accent2)
                            : Image.network(
                                photoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Icon(Icons.person_rounded, color: night ? Colors.white : accent2),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: primary, fontSize: 14.5, fontWeight: FontWeight.w900),
                          ),
                          if (hasEmail) ...[
                            const SizedBox(height: 2),
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: secondary, fontSize: 12.3, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (busy)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                  ],
                ),
                if (hasPhone || hasFecha) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (hasPhone)
                        _Chip(
                          night: night,
                          border: border,
                          text: "Tel: $phone",
                          primary: primary,
                        ),
                      if (hasFecha)
                        _Chip(
                          night: night,
                          border: border,
                          text: "Fecha: $fechaUnion",
                          primary: primary,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: onReject,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: const Color(0xFFE53935).withOpacity(0.7)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.close_rounded, color: Color(0xFFE53935)),
                          label: const Text(
                            "Rechazar",
                            style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: onApprove,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.check_rounded, color: Colors.white),
                          label: const Text(
                            "Aprobar",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final bool night;
  final Color border;
  final String text;
  final Color primary;

  const _Chip({
    required this.night,
    required this.border,
    required this.text,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: night ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.05),
        border: Border.all(color: border),
      ),
      child: Text(text, style: TextStyle(color: primary, fontSize: 11.5, fontWeight: FontWeight.w800)),
    );
  }
}
