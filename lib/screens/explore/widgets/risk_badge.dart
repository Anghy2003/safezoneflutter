import 'package:flutter/material.dart';

class RiskBadge extends StatelessWidget {
  final bool night;
  final bool isLoading;
  final String? nivel; // BAJO | MEDIO | ALTO
  final int? total;

  const RiskBadge({
    super.key,
    required this.night,
    required this.isLoading,
    required this.nivel,
    required this.total,
  });

  Color _chipColor(String nivel) {
    switch (nivel) {
      case "ALTO":
        return Colors.redAccent;
      case "MEDIO":
        return Colors.orangeAccent;
      default:
        return Colors.green;
    }
  }

  IconData _icon(String nivel) {
    switch (nivel) {
      case "ALTO":
        return Icons.warning_amber_rounded;
      case "MEDIO":
        return Icons.report_problem_outlined;
      default:
        return Icons.verified_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = (nivel ?? "BAJO").toUpperCase();

    // ✅ Para headers angostos: limita el ancho del chip
    // (Evita que el Row de arriba se reviente)
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 190),
      child: _pill(
        context: context,
        child: isLoading ? _loadingRow(context) : _dataRow(context, n),
      ),
    );
  }

  Widget _loadingRow(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: night ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            "Riesgo...",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: night ? Colors.white : Colors.black,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _dataRow(BuildContext context, String n) {
    final c = _chipColor(n);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_icon(n), size: 16, color: c),
        const SizedBox(width: 6),

        // ✅ Texto principal con ellipsis
        Flexible(
          child: Text(
            "Riesgo $n",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: night ? Colors.white : Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
            ),
          ),
        ),

        if (total != null) ...[
          const SizedBox(width: 6),

          // ✅ Contador controlado (no empuja el layout)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 60),
            child: Text(
              "($total)",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: night ? Colors.white60 : Colors.black54,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _pill({required BuildContext context, required Widget child}) {
    final w = MediaQuery.of(context).size.width;

    // ✅ Un poco más compacto en pantallas pequeñas
    final horizontal = w < 360 ? 10.0 : 12.0;
    final vertical = w < 360 ? 7.0 : 9.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      decoration: BoxDecoration(
        color: night
            ? Colors.white.withOpacity(0.06)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: night
              ? Colors.white.withOpacity(0.12)
              : Colors.black.withOpacity(0.08),
        ),
      ),
      child: child,
    );
  }
}
