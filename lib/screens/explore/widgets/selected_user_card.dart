import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng, Distance, LengthUnit;

import '../explore_models.dart';

class SelectedUserCard extends StatelessWidget {
  final bool night;
  final NearbyUser user;

  final LatLng center;

  /// Si tu app NO soporta ruta a usuario, estos dos normalmente vendrán null.
  /// Aun así los dejamos por compatibilidad.
  final double? routeDistanceM;
  final double? routeDurationS;
  final bool isLoadingRoute;

  /// Backend NO soporta ruta a usuario (solo a incidentes)
  /// Mantén canRoute, pero en este widget NO habilitamos ruta.
  final bool canRoute;
  final VoidCallback? onRoute;

  /// Quitar ruta activa (por ejemplo la ruta que venía desde un incidente)
  final VoidCallback? onClearRoute;

  /// Centrar mapa en el usuario
  final VoidCallback? onCenter;

  const SelectedUserCard({
    super.key,
    required this.night,
    required this.user,
    required this.center,
    required this.routeDistanceM,
    required this.routeDurationS,
    required this.isLoadingRoute,
    required this.canRoute,
    required this.onRoute,
    required this.onClearRoute,
    this.onCenter,
  });

  static const Color _accent = Color(0xFFFF5A5F);

  @override
  Widget build(BuildContext context) {
    final name = (user.name).trim().isNotEmpty ? user.name.trim() : 'Usuario';
    final avatarUrl = (user.avatarUrl ?? '').trim();
    final hasAvatar = avatarUrl.isNotEmpty;

    // Distancia “línea recta” (offline OK)
    final dMeters = const Distance().as(
      LengthUnit.Meter,
      center,
      LatLng(user.lat, user.lng),
    );
    final km = dMeters / 1000.0;

    // Si tu backend NO soporta ruta a usuario, se fuerza a false
    const bool routeSupportedForUser = false;

    // Ruta activa (normalmente es de incidente). Para permitir "Quitar ruta"
    // conviene NO depender de routeDistanceM/routeDurationS del usuario.
    final bool hasAnyRouteActive = (onClearRoute != null);

    final hasRouteInfo = routeDistanceM != null && routeDurationS != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: night ? const Color(0xFF0B0F14) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: night
              ? Colors.white.withOpacity(0.14)
              : Colors.black.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(night ? 0.35 : 0.12),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          _avatar(hasAvatar, avatarUrl, name),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: night ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 4),

                Text(
                  "Aprox.: ${km.toStringAsFixed(2)} km",
                  style: TextStyle(
                    color: night ? Colors.white70 : Colors.black54,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),

                // Si algún día decides soportar ruta a usuario y llenas estos campos,
                // aquí se mostrará.
                if (hasRouteInfo)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "Ruta: ${(routeDistanceM! / 1000).toStringAsFixed(2)} km · ${(routeDurationS! / 60).toStringAsFixed(0)} min",
                      style: TextStyle(
                        color: night ? Colors.white60 : Colors.black54,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),

                // Mensaje claro (solo si alguien intenta “rutar” a usuario)
                if (canRoute && !routeSupportedForUser)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      "Ruta a usuario no disponible (el backend solo calcula rutas a incidentes).",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: night ? Colors.white60 : Colors.black54,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                        height: 1.1,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          if (isLoadingRoute)
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: night ? Colors.white : _accent,
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onCenter != null)
                  IconButton(
                    tooltip: "Centrar",
                    onPressed: onCenter,
                    icon: Icon(
                      Icons.center_focus_strong_rounded,
                      color: night ? Colors.white70 : Colors.black54,
                      size: 24,
                    ),
                  ),

                // ✅ En tu caso: NO mostramos el botón Ruta porque siempre estaría deshabilitado.
                // Si quieres verlo deshabilitado por UI, te lo dejo comentado:
                /*
                IconButton(
                  tooltip: "Ruta",
                  onPressed: null,
                  icon: Icon(
                    Icons.directions,
                    color: night ? Colors.white24 : Colors.black26,
                    size: 26,
                  ),
                ),
                */

                // ✅ Quitar ruta aunque la ruta sea de incidente
                if (hasAnyRouteActive)
                  IconButton(
                    tooltip: "Quitar ruta",
                    onPressed: onClearRoute,
                    icon: const Icon(
                      Icons.close,
                      color: Colors.redAccent,
                      size: 26,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _avatar(bool hasAvatar, String avatarUrl, String name) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _accent.withOpacity(0.7), width: 2),
        color: night ? Colors.black87 : Colors.white,
      ),
      child: ClipOval(
        child: hasAvatar
            ? Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackInitial(name),
              )
            : _fallbackInitial(name),
      ),
    );
  }

  Widget _fallbackInitial(String name) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';
    return Container(
      color: const Color(0xFF111827),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
