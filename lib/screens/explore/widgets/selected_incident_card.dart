import 'package:flutter/material.dart';
import '../explore_models.dart';

class SelectedIncidentCard extends StatelessWidget {
  final bool night;
  final IncidenteLite inc;

  final bool isLoadingRoute;
  final double? routeDistanceM;
  final double? routeDurationS;

  final VoidCallback? onRoute;
  final VoidCallback? onClear;
  final VoidCallback? onClose;

  const SelectedIncidentCard({
    super.key,
    required this.night,
    required this.inc,
    required this.isLoadingRoute,
    required this.routeDistanceM,
    required this.routeDurationS,
    required this.onRoute,
    required this.onClear,
    required this.onClose,
  });

  static const Color _accent = Color(0xFFF95150);

  @override
  Widget build(BuildContext context) {
    final hasRoute = routeDistanceM != null && routeDurationS != null;
    final km = (routeDistanceM ?? 0) / 1000.0;
    final min = (routeDurationS ?? 0) / 60.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: night ? const Color(0xFF0B0F14) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: night ? Colors.white.withOpacity(0.14) : Colors.black.withOpacity(0.08),
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
          _badge(night),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (inc.tipo ?? 'INCIDENTE').toString(),
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
                  (inc.descripcion ?? 'Reporte cercano').toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: night ? Colors.white70 : Colors.black54,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    height: 1.15,
                  ),
                ),
                if (hasRoute)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      "Ruta: ${km.toStringAsFixed(2)} km · ${min.toStringAsFixed(0)} min",
                      style: TextStyle(
                        color: night ? Colors.white60 : Colors.black54,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
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
                IconButton(
                  tooltip: "Ruta",
                  onPressed: onRoute,
                  icon: const Icon(Icons.directions, color: _accent, size: 26),
                ),
                if (hasRoute)
                  IconButton(
                    tooltip: "Quitar ruta",
                    onPressed: onClear,
                    icon: const Icon(Icons.close, color: Colors.redAccent, size: 26),
                  ),
                IconButton(
                  tooltip: "Cerrar",
                  onPressed: onClose,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: night ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _badge(bool night) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: _accent.withOpacity(night ? 0.22 : 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent.withOpacity(0.55)),
      ),
      child: const Icon(Icons.warning_amber_rounded, color: _accent),
    );
  }
}
