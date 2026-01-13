// lib/screens/usage_policies_screen.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:another_telephony/telephony.dart';

import '../routes/app_routes.dart';

class UsagePoliciesScreen extends StatefulWidget {
  const UsagePoliciesScreen({super.key});

  @override
  State<UsagePoliciesScreen> createState() => _UsagePoliciesScreenState();
}

class _UsagePoliciesScreenState extends State<UsagePoliciesScreen> {
  static const String kPoliciesAccepted = "policies_accepted_v1";
  static const String kAskedSmsPermission = "asked_sms_permission_v1";
  static const String kSmsPermissionGranted = "sms_permission_granted_v1";

  final ScrollController _scroll = ScrollController();

  bool _accepted = false;
  bool _isDark = false;

  bool _smsToggle = false;
  bool _smsBusy = false;
  bool _smsGranted = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool(kPoliciesAccepted) ?? false;
    final granted = prefs.getBool(kSmsPermissionGranted) ?? false;

    if (!mounted) return;
    setState(() {
      _accepted = accepted; // si ya aceptó antes, lo marcamos
      _smsGranted = granted;
      _smsToggle = granted; // si ya está concedido, dejamos toggle ON
    });

    // Si ya aceptó antes, continúa directo a Splash (para no molestar).
    if (accepted && mounted) {
      AppRoutes.navigateAndClearStack(context, AppRoutes.splash);
    }
  }

  Future<void> _requestSmsPermissionFlow() async {
    if (_smsBusy) return;

    setState(() => _smsBusy = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // Marcamos que ya preguntamos (para no insistir luego)
      await prefs.setBool(kAskedSmsPermission, true);

      if (!mounted) return;

      // Diálogo previo (explicación + consentimiento)
      final allow = await _showSmsPermissionDialog();
      if (!allow) {
        // Si el usuario dice "Ahora no", apagamos toggle y listo.
        await prefs.setBool(kSmsPermissionGranted, false);
        if (!mounted) return;
        setState(() {
          _smsToggle = false;
          _smsGranted = false;
        });
        return;
      }

      final telephony = Telephony.instance;

      final canSend = (await telephony.isSmsCapable) ?? false;
      if (!canSend) {
        await prefs.setBool(kSmsPermissionGranted, false);
        if (!mounted) return;
        setState(() {
          _smsToggle = false;
          _smsGranted = false;
        });

        _toast(
          "Este dispositivo no soporta SMS.",
          isError: true,
        );
        return;
      }

      // another_telephony: pide permisos de SMS (SEND_SMS)
      final bool? granted = await telephony.requestSmsPermissions;

      await prefs.setBool(kSmsPermissionGranted, granted == true);

      if (!mounted) return;
      setState(() {
        _smsGranted = granted == true;
        _smsToggle = granted == true;
      });

      if (granted == true) {
        _toast("Permiso SMS habilitado.");
      } else {
        _toast("Permiso SMS denegado.", isError: true);
      }
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kSmsPermissionGranted, false);

      if (!mounted) return;
      setState(() {
        _smsToggle = false;
        _smsGranted = false;
      });

      _toast("Error solicitando permiso SMS.", isError: true);
    } finally {
      if (mounted) setState(() => _smsBusy = false);
    }
  }

  Future<bool> _showSmsPermissionDialog() async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: _isDark ? const Color(0xFF0E1322) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            "Permiso para SMS",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: _isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
            ),
          ),
          content: Text(
            "SafeZone puede enviar un SMS automático a tus contactos en una emergencia, "
            "sin abrir apps y sin que tengas que presionar “Enviar”.\n\n"
            "Esto utiliza el saldo/plan de SMS de tu operador.\n\n"
            "¿Deseas habilitarlo?",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _isDark ? const Color(0xFFA9B1C3) : const Color(0xFF475569),
              height: 1.35,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Ahora no"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                "Habilitar",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );

    return res == true;
  }

  Future<void> _acceptAndContinue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPoliciesAccepted, true);

    if (!mounted) return;
    AppRoutes.navigateAndClearStack(context, AppRoutes.splash);
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.redAccent : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _isDark = Theme.of(context).brightness == Brightness.dark;

    const red1 = Color(0xFFFF5A5A);
    const red2 = Color(0xFFE53935);

    final bg = _isDark ? const Color(0xFF05070A) : const Color(0xFFF3F4F6);
    final primaryText = _isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
    final secondaryText = _isDark ? Colors.white.withOpacity(0.70) : const Color(0xFF475569);

    final cardFill = _isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.90);
    final cardBorder = _isDark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Fondo suave
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: _isDark
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF05070A), Color(0xFF000000)],
                      )
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFFF5F5), Color(0xFFFFEBEE), Color(0xFFFFFFFF)],
                      ),
              ),
            ),
          ),

          // Orbes
          Positioned(
            top: 90,
            right: -60,
            child: _glowCircle(
              diameter: 180,
              colors: _isDark ? const [Color(0xFFFFCDD2), Color(0xFFE53935)] : const [Color(0xFFFFEBEE), Color(0xFFE53935)],
              glowOpacity: _isDark ? 0.55 : 0.18,
            ),
          ),
          Positioned(
            bottom: -70,
            left: -40,
            child: _glowCircle(
              diameter: 220,
              colors: _isDark ? const [Color(0xFFFFEBEE), Color(0xFFB71C1C)] : const [Color(0xFFFFCDD2), Color(0xFFE53935)],
              glowOpacity: _isDark ? 0.55 : 0.14,
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [red1, red2]),
                        ),
                        child: const Icon(Icons.policy_outlined, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Políticas de uso",
                          style: TextStyle(
                            color: primaryText,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Contenido
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardFill,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: cardBorder),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Scrollbar(
                            controller: _scroll,
                            child: ListView(
                              controller: _scroll,
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                              children: [
                                Text(
                                  "Antes de continuar",
                                  style: TextStyle(
                                    color: primaryText,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "SafeZone está diseñado para seguridad comunitaria. Para proteger a la comunidad y evitar abusos, aplicamos reglas de uso y sanciones.",
                                  style: TextStyle(color: secondaryText, height: 1.35, fontWeight: FontWeight.w600),
                                ),

                                const SizedBox(height: 14),
                                _sectionTitle("1) SMS automático en emergencias", primaryText),
                                _bullet(
                                  "Si habilitas SMS, SafeZone puede enviar mensajes automáticos a tus contactos durante una emergencia.",
                                  secondaryText,
                                ),
                                _bullet(
                                  "El envío usa tu saldo/plan del operador (puede generar costos).",
                                  secondaryText,
                                ),
                                _bullet(
                                  "Puedes continuar sin habilitar SMS; la app seguirá funcionando, pero con menos automatización.",
                                  secondaryText,
                                ),

                                const SizedBox(height: 12),
                                _smsCard(primaryText, secondaryText, red1, red2),

                                const SizedBox(height: 14),
                                _sectionTitle("2) Ubicación y precisión", primaryText),
                                _bullet(
                                  "La ubicación se utiliza para ubicar incidentes, alertas cercanas y mejorar la respuesta comunitaria.",
                                  secondaryText,
                                ),
                                _bullet(
                                  "Tu ubicación puede ser compartida con tu comunidad durante una alerta, según tu configuración.",
                                  secondaryText,
                                ),

                                const SizedBox(height: 14),
                                _sectionTitle("3) Anti-abuso y sanciones", primaryText),
                                _bullet(
                                  "Si se envían 3 alertas desde los botones de emergencia en un rango de 1 hora, la cuenta será penalizada.",
                                  secondaryText,
                                ),
                                _bullet(
                                  "Penalización: bloqueo de acceso por 15 días (sin posibilidad de uso).",
                                  secondaryText,
                                ),
                                _bullet(
                                  "Reportes falsos, spam, acoso, suplantación o uso malintencionado pueden generar sanción inmediata y/o bloqueo permanente.",
                                  secondaryText,
                                ),

                                const SizedBox(height: 14),
                                _sectionTitle("4) Privacidad y seguridad", primaryText),
                                _bullet(
                                  "Podemos registrar eventos técnicos (p. ej., hora de alerta, estado de entrega, identificadores) para auditoría y prevención de abuso.",
                                  secondaryText,
                                ),
                                _bullet(
                                  "Nunca compartas códigos, datos sensibles o información personal con desconocidos.",
                                  secondaryText,
                                ),

                                const SizedBox(height: 14),
                                _sectionTitle("5) Conducta en comunidades", primaryText),
                                _bullet(
                                  "Respeta a los miembros, evita contenido violento explícito, ilegal o discriminatorio.",
                                  secondaryText,
                                ),
                                _bullet(
                                  "El administrador de comunidad puede expulsar miembros y reportar abusos.",
                                  secondaryText,
                                ),

                                const SizedBox(height: 18),
                                _acceptRow(primaryText, secondaryText),

                                const SizedBox(height: 8),
                                Text(
                                  "Al continuar confirmas que comprendes estas reglas y aceptas su aplicación.",
                                  style: TextStyle(color: secondaryText, fontSize: 12, height: 1.25, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // CTA
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _accepted ? _acceptAndContinue : null,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: _accepted ? 1.0 : 0.55,
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: const LinearGradient(colors: [red1, red2]),
                              boxShadow: [
                                BoxShadow(
                                  color: red2.withOpacity(_isDark ? 0.55 : 0.20),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                )
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              "Aceptar y continuar",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Puedes revisar estas políticas desde Menú > Seguridad.",
                        style: TextStyle(color: secondaryText, fontSize: 11, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w900,
        fontSize: 13.5,
      ),
    );
  }

  Widget _bullet(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(Icons.check_circle_outline, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, height: 1.3, fontWeight: FontWeight.w600, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _smsCard(Color primaryText, Color secondaryText, Color red1, Color red2) {
    final bg = _isDark ? Colors.black.withOpacity(0.25) : Colors.white.withOpacity(0.92);
    final border = _isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.06);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [red1, red2]),
            ),
            child: const Icon(Icons.sms_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Habilitar SMS automático",
                  style: TextStyle(color: primaryText, fontWeight: FontWeight.w900, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  _smsGranted
                      ? "Permiso concedido. SafeZone podrá enviar SMS en emergencias."
                      : "Opcional. Recomendado para emergencias sin internet.",
                  style: TextStyle(color: secondaryText, fontWeight: FontWeight.w700, fontSize: 11.5, height: 1.2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _smsBusy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : Switch(
                  value: _smsToggle,
                  onChanged: (v) async {
                    // Si el usuario apaga, guardamos OFF (no revoca permiso, pero desactiva uso en app)
                    if (!v) {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool(kSmsPermissionGranted, false);
                      if (!mounted) return;
                      setState(() {
                        _smsToggle = false;
                        _smsGranted = false;
                      });
                      return;
                    }

                    // Si enciende: flujo de permiso
                    await _requestSmsPermissionFlow();
                  },
                ),
        ],
      ),
    );
  }

  Widget _acceptRow(Color primaryText, Color secondaryText) {
    final border = _isDark ? Colors.white.withOpacity(0.14) : Colors.black.withOpacity(0.08);
    final bg = _isDark ? Colors.black.withOpacity(0.18) : Colors.white.withOpacity(0.92);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _accepted,
            onChanged: (v) => setState(() => _accepted = v ?? false),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              "He leído y acepto las políticas de uso de SafeZone.",
              style: TextStyle(color: secondaryText, fontWeight: FontWeight.w700, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowCircle({
    required double diameter,
    required List<Color> colors,
    required double glowOpacity,
  }) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: colors,
          center: Alignment.topLeft,
          radius: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withOpacity(glowOpacity),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
    );
  }
}
