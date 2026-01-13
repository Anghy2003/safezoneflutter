// lib/screens/penalized_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../routes/app_routes.dart';

class PenalizedScreen extends StatefulWidget {
  const PenalizedScreen({super.key});

  @override
  State<PenalizedScreen> createState() => _PenalizedScreenState();
}

class _PenalizedScreenState extends State<PenalizedScreen> {
  static const String kPenaltyUntil = "penalty_until_iso_v1";

  DateTime? _until;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(kPenaltyUntil);
    if (iso != null) {
      final dt = DateTime.tryParse(iso);
      if (mounted) setState(() => _until = dt);
    }
  }

  String _fmtRemaining() {
    if (_until == null) return "—";
    final now = DateTime.now();
    if (!now.isBefore(_until!)) return "0d 0h";

    final diff = _until!.difference(now);
    final d = diff.inDays;
    final h = diff.inHours % 24;
    final m = diff.inMinutes % 60;
    return "${d}d ${h}h ${m}m";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const red1 = Color(0xFFFF5A5A);
    const red2 = Color(0xFFE53935);

    final bg = isDark ? const Color(0xFF05070A) : const Color(0xFFFFF5F5);
    final title = isDark ? Colors.white : const Color(0xFF111827);
    final sub = isDark ? Colors.white.withOpacity(0.75) : const Color(0xFF475569);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Center(
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(colors: [red1, red2]),
                boxShadow: [
                  BoxShadow(
                    color: red2.withOpacity(isDark ? 0.60 : 0.22),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withOpacity(0.35) : Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 52, color: title),
                    const SizedBox(height: 10),
                    Text(
                      "Acceso temporalmente bloqueado",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: title,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Detectamos uso excesivo de alertas en un periodo corto.\n"
                      "Para proteger a la comunidad, tu cuenta fue penalizada.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: sub, fontWeight: FontWeight.w700, height: 1.25),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Tiempo restante: ${_fmtRemaining()}",
                      style: TextStyle(color: title, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: red2,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          // Reintenta el gate: si ya venció, te deja pasar
                          AppRoutes.navigateAndClearStack(context, AppRoutes.splash);
                        },
                        child: const Text("Reintentar", style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
