import 'package:flutter/material.dart';
import '../explore_models.dart';

class IncidentPin extends StatelessWidget {
  final IncidenteLite inc;
  final bool night;
  final bool selected;

  const IncidentPin({
    super.key,
    required this.inc,
    required this.night,
    required this.selected,
  });

  IconData _iconForTipo(String? tipo) {
    final t = (tipo ?? '').toUpperCase();

    if (t.contains('AGRES') || t.contains('VIOL') || t.contains('AMENAZ'))
      return Icons.gpp_maybe_rounded;

    if (t.contains('ROBO') || t.contains('ASAL'))
      return Icons.local_police_outlined;

    if (t.contains('INCEND') || t.contains('FUEGO'))
      return Icons.local_fire_department_rounded;

    if (t.contains('ACCID') || t.contains('CHOQUE'))
      return Icons.car_crash_rounded;

    if (t.contains('MED') || t.contains('SALUD'))
      return Icons.medical_services_rounded;

    return Icons.report_gmailerrorred_rounded;
  }

  Color _accentForTipo(String? tipo) {
    final t = (tipo ?? '').toUpperCase();

    if (t.contains('INCEND') || t.contains('FUEGO')) return Colors.orangeAccent;
    if (t.contains('AGRES') || t.contains('VIOL') || t.contains('ROBO') || t.contains('ASAL'))
      return Colors.redAccent;
    if (t.contains('MED') || t.contains('SALUD')) return Colors.lightBlueAccent;

    return const Color(0xFFFF5A5F);
  }

  @override
  Widget build(BuildContext context) {
    final tipo = (inc.tipo ?? 'INCIDENTE').toString();
    final accent = _accentForTipo(tipo);
    final icon = _iconForTipo(tipo);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 190),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: night ? const Color(0xFF0B0F14) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? accent.withOpacity(0.95) : accent.withOpacity(0.35),
              width: selected ? 2.0 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(night ? 0.35 : 0.18),
                blurRadius: 14,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withOpacity(night ? 0.22 : 0.16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withOpacity(0.65)),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tipo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: night ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (inc.descripcion ?? 'Reporte cercano').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: night ? Colors.white70 : Colors.black54,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        CustomPaint(
          size: const Size(14, 8),
          painter: _TrianglePainter(color: accent.withOpacity(0.9)),
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter old) => old.color != color;
}
