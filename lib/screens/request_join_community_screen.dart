import 'dart:ui';
import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../service/community_join_service.dart';

class RequestJoinCommunityScreen extends StatefulWidget {
  const RequestJoinCommunityScreen({super.key});

  @override
  State<RequestJoinCommunityScreen> createState() =>
      _RequestJoinCommunityScreenState();
}

class _RequestJoinCommunityScreenState extends State<RequestJoinCommunityScreen> {
  final _svc = CommunityJoinService();

  bool _isLoading = false;
  String? _errorText;

  int? _communityId;
  String? _communityName;
  String? _communityPhotoUrl;

  bool _argsLoaded = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (!_argsLoaded) {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is Map) {
          _communityId = (args["communityId"] as num?)?.toInt();
          _communityName = args["communityName"]?.toString();
          _communityPhotoUrl = args["communityPhotoUrl"]?.toString();
        }
        _argsLoaded = true;
      }

      setState(() {});
    });
  }

  bool get isNightMode => Theme.of(context).brightness == Brightness.dark;

  void _setError(String? msg) {
    if (!mounted) return;
    setState(() => _errorText = msg);
  }

  Future<void> _handleRequestJoin() async {
    final comunidadId = _communityId;
    if (comunidadId == null) {
      _setError("No se pudo identificar la comunidad.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final userId = await _svc.getUserId();
      if (userId == null) {
        _setError("Error interno: usuario no encontrado. Vuelve a iniciar sesión.");
        return;
      }

      final resp = await _svc.requestJoinCommunity(
        userId: userId,
        communityId: comunidadId,
      );

      if (resp == null) {
        _setError("No se pudo enviar la solicitud.");
        return;
      }

      if (resp["_error"] != null) {
        final e = resp["_error"];
        if (e == "NO_INTERNET") _setError("Sin internet. Verifica tu conexión.");
        else if (e == "TIMEOUT") _setError("Tiempo de espera agotado.");
        else _setError("No se pudo enviar la solicitud.");
        return;
      }

      final estado = (resp["estado"] ?? "").toString().toLowerCase();

      await _svc.saveCommunityId(comunidadId);

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Color(0xFFE53935)),
              SizedBox(width: 10),
              Expanded(child: Text("Solicitud enviada")),
            ],
          ),
          content: Text(
            estado == "pendiente"
                ? "Tu solicitud quedó PENDIENTE.\n\nUn administrador debe aprobarte. Te llegará una notificación cuando ya puedas unirte."
                : "Tu estado actual es: $estado",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Entendido"),
            ),
          ],
        ),
      );

      if (!mounted) return;
      // UX: llévalo a “Mis comunidades” para ver el estado (pendiente/activo)
      AppRoutes.navigateAndClearStack(context, AppRoutes.myCommunities);
    } catch (_) {
      _setError("No se pudo conectar con el servidor.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

    final name = (_communityName ?? "Comunidad").trim();
    final photo = (_communityPhotoUrl ?? "").trim();

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
                      "Solicitar unirse",
                      style: TextStyle(color: primary, fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: border),
                            boxShadow: [BoxShadow(color: shadow, blurRadius: 18, offset: const Offset(0, 10))],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // header
                              Row(
                                children: [
                                  Container(
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      gradient: LinearGradient(
                                        colors: [accent1.withOpacity(0.35), accent2.withOpacity(0.25)],
                                      ),
                                      border: Border.all(color: border),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: photo.isEmpty
                                          ? Icon(Icons.groups_rounded, color: night ? Colors.white : accent2, size: 28)
                                          : Image.network(
                                              photo,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Icon(Icons.groups_rounded, color: night ? Colors.white : accent2),
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
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: primary, fontSize: 15.5, fontWeight: FontWeight.w900),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Envía tu solicitud para unirte.",
                                          style: TextStyle(color: secondary, fontSize: 12.5, fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: night ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: border),
                                ),
                                child: Text(
                                  "El administrador debe aprobarte para que puedas ver el chat y alertas de la comunidad.",
                                  style: TextStyle(color: secondary, fontSize: 12.8, fontWeight: FontWeight.w600),
                                ),
                              ),

                              if (_errorText != null) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.error_outline, size: 16, color: accent2),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorText!,
                                        style: const TextStyle(color: accent2, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              const SizedBox(height: 14),

                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleRequestJoin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accent2,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.2,
                                          ),
                                        )
                                      : const Text(
                                          "Solicitar unirse",
                                          style: TextStyle(fontWeight: FontWeight.w900),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 10),

                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: OutlinedButton(
                                  onPressed: _isLoading ? null : () => AppRoutes.goBack(context),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: border),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  child: Text(
                                    "Cancelar",
                                    style: TextStyle(color: primary, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
