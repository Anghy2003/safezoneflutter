// lib/screens/explore/widgets/selected_user_card.dart

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng, Distance, LengthUnit;

import '../explore_models.dart';

/// =============================================================
/// TARJETA DEL USUARIO SELECCIONADO
/// =============================================================
/// Uso:
/// SelectedUserCard(
///   night: night,
///   user: selectedUser,
///   center: center,
///   routeDistanceM: routeDistanceM,
///   routeDurationS: routeDurationS,
///   isLoadingRoute: isLoadingRoute,
///   canRoute: incidenteIdFromReport != null,
///   onRoute: () => loadRoute(),
///   onClearRoute: clearRoute,
/// )
class SelectedUserCard extends StatelessWidget {
  final bool night;
  final NearbyUser user;
  final LatLng center;

  final double? routeDistanceM;
  final double? routeDurationS;
  final bool isLoadingRoute;

  /// Si el modal viene desde Reporte (tiene incidentId)
  final bool canRoute;

  /// Carga la ruta (normalmente: ctrl.loadRouteToIncident(id))
  final VoidCallback? onRoute;

  /// Limpia la ruta (ctrl.clearRoute)
  final VoidCallback? onClearRoute;

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
  });

  @override
  Widget build(BuildContext context) {
    final distanceKm = Distance().as(
      LengthUnit.Kilometer,
      center,
      LatLng(user.lat, user.lng),
    );

    final hasRoute = routeDistanceM != null && routeDurationS != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: night ? const Color(0xFF0B0F14) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: night
              ? Colors.white.withOpacity(0.15)
              : Colors.black.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          _buildAvatar(),
          const SizedBox(width: 12),
          _buildInfo(distanceKm: distanceKm, hasRoute: hasRoute),
          const SizedBox(width: 8),
          _buildActions(hasRoute: hasRoute),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // AVATAR
  // -------------------------------------------------------------
  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFFFF5A5F),
      child: user.avatarUrl == null
          ? const Icon(Icons.person, color: Colors.white, size: 28)
          : ClipOval(
              child: Image.network(
                user.avatarUrl!,
                fit: BoxFit.cover,
                width: 48,
                height: 48,
              ),
            ),
    );
  }

  // -------------------------------------------------------------
  // INFORMACIÓN DEL USUARIO
  // -------------------------------------------------------------
  Widget _buildInfo({
    required double distanceKm,
    required bool hasRoute,
  }) {
    final routeKm = (routeDistanceM ?? 0) / 1000.0;
    final routeMin = (routeDurationS ?? 0) / 60.0;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            user.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: night ? Colors.white : Colors.black,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "A ${distanceKm.toStringAsFixed(2)} km",
            style: TextStyle(
              color: night ? Colors.white60 : Colors.black54,
              fontSize: 13,
            ),
          ),
          if (hasRoute)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                "Ruta: ${routeKm.toStringAsFixed(2)} km · ${routeMin.toStringAsFixed(0)} min",
                style: TextStyle(
                  color: night ? Colors.white70 : Colors.black54,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // ACCIONES (RUTA / LIMPIAR)
  // -------------------------------------------------------------
  Widget _buildActions({required bool hasRoute}) {
    if (isLoadingRoute) {
      return SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: night ? Colors.white : const Color(0xFF3B82F6),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: canRoute
              ? 'Ruta al incidente'
              : 'No hay incidente (abre desde Reporte)',
          onPressed: canRoute ? onRoute : null,
          icon: Icon(
            Icons.directions,
            color: canRoute ? const Color(0xFF3B82F6) : Colors.grey,
            size: 26,
          ),
        ),
        if (hasRoute)
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
    );
  }
}
