// lib/widgets/safety_tips_carousel.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ✅ Tipo de contenido del slide (para diferenciar por título)
enum TipKind { tip, motivacion, curioso }

extension TipKindX on TipKind {
  String get label {
    switch (this) {
      case TipKind.tip:
        return "Consejo";
      case TipKind.motivacion:
        return "Motivación";
      case TipKind.curioso:
        return "Dato curioso";
    }
  }

  IconData get icon {
    switch (this) {
      case TipKind.tip:
        return Icons.info_rounded;
      case TipKind.motivacion:
        return Icons.favorite_rounded;
      case TipKind.curioso:
        return Icons.lightbulb_rounded;
    }
  }
}

class SafetyTip {
  /// ✅ Ej: "Médica", "Fuego", etc.
  final String category;

  /// ✅ Consejo | Motivación | Dato curioso
  final TipKind kind;

  /// ✅ Título visible del chip: "Médica · Consejo"
  final String title;

  final String message;
  final IconData icon;
  final List<Color> gradient;
  final Color accent;

  const SafetyTip({
    required this.category,
    required this.kind,
    required this.title,
    required this.message,
    required this.icon,
    required this.gradient,
    required this.accent,
  });
}

class SafetyTipsCarousel extends StatefulWidget {
  final bool nightMode;
  final double height;
  final Duration autoPlayInterval;

  /// ✅ Tap en el slide: te devuelve el tip actual
  final ValueChanged<SafetyTip>? onTipTap;

  /// ✅ Haptic feedback (pro)
  final bool enableHaptics;

  const SafetyTipsCarousel({
    super.key,
    required this.nightMode,
    this.height = 148, // ⬅️ un poco más alto (ahora hay 20 mensajes)
    this.autoPlayInterval = const Duration(seconds: 5),
    this.onTipTap,
    this.enableHaptics = true,
  });

  @override
  State<SafetyTipsCarousel> createState() => _SafetyTipsCarouselState();
}

class _SafetyTipsCarouselState extends State<SafetyTipsCarousel>
    with TickerProviderStateMixin {
  final PageController _controller = PageController();

  Timer? _timer;
  int _index = 0;

  late final AnimationController _shineCtrl;
  late final AnimationController _pulseCtrl;

  bool _userInteracting = false;

  // ✅ 20 slides (por categoría: consejo + motivación + curioso, con extras)
  late final List<SafetyTip> _tips = const [
    // ============================ MÉDICA (4) ============================
    SafetyTip(
      category: "Médica",
      kind: TipKind.tip,
      title: "Médica · Consejo",
      message:
          "Si hay sangrado o desmayo: presiona con un paño limpio, eleva si es posible y mantén a la persona acompañada.",
      icon: Icons.local_hospital_rounded,
      gradient: [Color(0xFFE8FFF7), Color(0xFFDDF7FF)],
      accent: Color(0xFF4CC9A6),
    ),
    SafetyTip(
      category: "Médica",
      kind: TipKind.motivacion,
      title: "Médica · Motivación",
      message:
          "Respira. Tu calma es una herramienta. Llamar y acompañar ya es una gran ayuda.",
      icon: Icons.favorite_rounded,
      gradient: [Color(0xFFE8FFF7), Color(0xFFDDF7FF)],
      accent: Color(0xFF4CC9A6),
    ),
    SafetyTip(
      category: "Médica",
      kind: TipKind.curioso,
      title: "Médica · Dato curioso",
      message:
          "En primeros auxilios, los minutos cuentan: una respuesta rápida mejora mucho el pronóstico en emergencias críticas.",
      icon: Icons.lightbulb_rounded,
      gradient: [Color(0xFFE8FFF7), Color(0xFFDDF7FF)],
      accent: Color(0xFF4CC9A6),
    ),
    SafetyTip(
      category: "Médica",
      kind: TipKind.tip,
      title: "Médica · Extra",
      message:
          "Si la persona está inconsciente pero respira: colócala de lado (posición lateral de seguridad) y vigila su respiración.",
      icon: Icons.health_and_safety_rounded,
      gradient: [Color(0xFFE8FFF7), Color(0xFFDDF7FF)],
      accent: Color(0xFF4CC9A6),
    ),

    // ============================= FUEGO (3) ============================
    SafetyTip(
      category: "Fuego",
      kind: TipKind.tip,
      title: "Fuego · Consejo",
      message:
          "Evacúa primero. No uses ascensor. Si hay humo: agáchate y cúbrete nariz y boca con tela.",
      icon: Icons.local_fire_department_rounded,
      gradient: [Color(0xFFFFF0E6), Color(0xFFFFE2E2)],
      accent: Color(0xFFFF5A5F),
    ),
    SafetyTip(
      category: "Fuego",
      kind: TipKind.motivacion,
      title: "Fuego · Motivación",
      message:
          "Decidir rápido y salir con orden salva vidas. Tú puedes guiar a otros con claridad.",
      icon: Icons.favorite_rounded,
      gradient: [Color(0xFFFFF0E6), Color(0xFFFFE2E2)],
      accent: Color(0xFFFF5A5F),
    ),
    SafetyTip(
      category: "Fuego",
      kind: TipKind.curioso,
      title: "Fuego · Dato curioso",
      message:
          "El humo suele ser más peligroso que las llamas: reduce la visibilidad y afecta la respiración en poco tiempo.",
      icon: Icons.lightbulb_rounded,
      gradient: [Color(0xFFFFF0E6), Color(0xFFFFE2E2)],
      accent: Color(0xFFFF5A5F),
    ),

    // ============================ DESASTRE (3) ===========================
    SafetyTip(
      category: "Desastre",
      kind: TipKind.tip,
      title: "Desastre · Consejo",
      message:
          "Aléjate de cables y estructuras inestables. Ubícate en un punto abierto y reporta tu zona.",
      icon: Icons.domain_rounded,
      gradient: [Color(0xFFEAF2FF), Color(0xFFEFF7FF)],
      accent: Color(0xFF5C9ECC),
    ),
    SafetyTip(
      category: "Desastre",
      kind: TipKind.motivacion,
      title: "Desastre · Motivación",
      message:
          "Tu comunidad es más fuerte cuando tú te organizas. Un paso a la vez, con foco y serenidad.",
      icon: Icons.favorite_rounded,
      gradient: [Color(0xFFEAF2FF), Color(0xFFEFF7FF)],
      accent: Color(0xFF5C9ECC),
    ),
    SafetyTip(
      category: "Desastre",
      kind: TipKind.curioso,
      title: "Desastre · Dato curioso",
      message:
          "Tras un sismo o evento fuerte, pueden ocurrir réplicas: por eso conviene mantenerse en áreas seguras y abiertas.",
      icon: Icons.lightbulb_rounded,
      gradient: [Color(0xFFEAF2FF), Color(0xFFEFF7FF)],
      accent: Color(0xFF5C9ECC),
    ),

    // ============================ ACCIDENTE (3) ==========================
    SafetyTip(
      category: "Accidente",
      kind: TipKind.tip,
      title: "Accidente · Consejo",
      message:
          "Señaliza si es seguro. No muevas heridos con dolor fuerte en cuello o espalda. Llama a emergencias.",
      icon: Icons.car_crash_rounded,
      gradient: [Color(0xFFF4EFFF), Color(0xFFEFE9FF)],
      accent: Color(0xFFB574F0),
    ),
    SafetyTip(
      category: "Accidente",
      kind: TipKind.motivacion,
      title: "Accidente · Motivación",
      message:
          "Tu prudencia vale oro. Proteger la escena evita más víctimas. Actúa con cabeza fría.",
      icon: Icons.favorite_rounded,
      gradient: [Color(0xFFF4EFFF), Color(0xFFEFE9FF)],
      accent: Color(0xFFB574F0),
    ),
    SafetyTip(
      category: "Accidente",
      kind: TipKind.curioso,
      title: "Accidente · Dato curioso",
      message:
          "Una escena bien señalizada reduce riesgos secundarios. La seguridad del entorno es parte del auxilio.",
      icon: Icons.lightbulb_rounded,
      gradient: [Color(0xFFF4EFFF), Color(0xFFEFE9FF)],
      accent: Color(0xFFB574F0),
    ),

    // ============================ VIOLENCIA (3) ==========================
    SafetyTip(
      category: "Violencia",
      kind: TipKind.tip,
      title: "Violencia · Consejo",
      message:
          "Tu vida es primero: aléjate, busca un sitio iluminado y pide ayuda cuando estés a salvo.",
      icon: Icons.shield_rounded,
      gradient: [Color(0xFFFFEAF2), Color(0xFFFFE2EB)],
      accent: Color(0xFFF06292),
    ),
    SafetyTip(
      category: "Violencia",
      kind: TipKind.motivacion,
      title: "Violencia · Motivación",
      message:
          "No estás sola/solo. Pedir ayuda a tiempo es valentía. Tu seguridad es prioridad.",
      icon: Icons.favorite_rounded,
      gradient: [Color(0xFFFFEAF2), Color(0xFFFFE2EB)],
      accent: Color(0xFFF06292),
    ),
    SafetyTip(
      category: "Violencia",
      kind: TipKind.curioso,
      title: "Violencia · Dato curioso",
      message:
          "Tener un plan simple (rutas, contactos, puntos seguros) reduce el tiempo de reacción cuando ocurre una amenaza.",
      icon: Icons.lightbulb_rounded,
      gradient: [Color(0xFFFFEAF2), Color(0xFFFFE2EB)],
      accent: Color(0xFFF06292),
    ),

    // ============================== ROBO (4) =============================
    SafetyTip(
      category: "Robo",
      kind: TipKind.tip,
      title: "Robo · Consejo",
      message:
          "No enfrentes al agresor. Observa rasgos y dirección de huida; reporta y comparte ubicación.",
      icon: Icons.person_off_rounded,
      gradient: [Color(0xFFFFF7E1), Color(0xFFFFEFC7)],
      accent: Color(0xFFF7D774),
    ),
    SafetyTip(
      category: "Robo",
      kind: TipKind.motivacion,
      title: "Robo · Motivación",
      message:
          "Lo material se recupera; tu integridad no. Mantén la calma y toma control cuando estés a salvo.",
      icon: Icons.favorite_rounded,
      gradient: [Color(0xFFFFF7E1), Color(0xFFFFEFC7)],
      accent: Color(0xFFF7D774),
    ),
    SafetyTip(
      category: "Robo",
      kind: TipKind.curioso,
      title: "Robo · Dato curioso",
      message:
          "Recordar detalles concretos (ropa, estatura, dirección) ayuda más que suposiciones. Anótalo apenas puedas.",
      icon: Icons.lightbulb_rounded,
      gradient: [Color(0xFFFFF7E1), Color(0xFFFFEFC7)],
      accent: Color(0xFFF7D774),
    ),
    SafetyTip(
      category: "Robo",
      kind: TipKind.tip,
      title: "Robo · Extra",
      message:
          "Si estás en casa: no abras a desconocidos. Verifica por mirilla/cámara y confirma identidad antes de permitir el ingreso.",
      icon: Icons.lock_rounded,
      gradient: [Color(0xFFFFF7E1), Color(0xFFFFEFC7)],
      accent: Color(0xFFF7D774),
    ),
  ];

  @override
  void initState() {
    super.initState();

    _shineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);

    _startAutoPlay();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _shineCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.autoPlayInterval, (_) async {
      if (!mounted) return;
      if (_userInteracting) return;
      if (!_controller.hasClients) return;

      final next = (_index + 1) % _tips.length;
      await _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 560),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _setUserInteracting(bool value) {
    if (_userInteracting == value) return;
    setState(() => _userInteracting = value);

    if (!value) {
      Future.delayed(const Duration(milliseconds: 850), () {
        if (!mounted) return;
        setState(() => _userInteracting = false);
      });
    }
  }

  void _handleTap() {
    final cb = widget.onTipTap;
    if (cb == null) return;

    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    cb(_tips[_index]);
  }

  @override
  Widget build(BuildContext context) {
    final night = widget.nightMode;

    final Color border =
        night ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.06);

    return SizedBox(
      height: widget.height,
      child: Listener(
        onPointerDown: (_) => _setUserInteracting(true),
        onPointerUp: (_) => _setUserInteracting(false),
        onPointerCancel: (_) => _setUserInteracting(false),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(night ? 0.50 : 0.10),
                    blurRadius: 26,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _handleTap,
                    splashColor: Colors.white.withOpacity(0.10),
                    highlightColor: Colors.white.withOpacity(0.06),
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _tips.length,
                      onPageChanged: (i) {
                        setState(() => _index = i);
                        if (widget.enableHaptics) {
                          HapticFeedback.selectionClick();
                        }
                      },
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, i) {
                        return _TipSlide(
                          tip: _tips[i],
                          night: night,
                          shine: _shineCtrl,
                          pulse: _pulseCtrl,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: _DotsIndicator(
                length: _tips.length,
                index: _index,
                night: night,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipSlide extends StatelessWidget {
  final SafetyTip tip;
  final bool night;
  final Animation<double> shine;
  final Animation<double> pulse;

  const _TipSlide({
    required this.tip,
    required this.night,
    required this.shine,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = night
        ? const [Color(0xFF0E1322), Color(0xFF171D33)]
        : tip.gradient;

    final Color msgColor = night ? Colors.white70 : const Color(0xFF334155);

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),

        // halo suave
        Positioned(
          top: -40,
          left: -40,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tip.accent.withOpacity(night ? 0.14 : 0.12),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // icono con pulso
              AnimatedBuilder(
                animation: pulse,
                builder: (_, __) {
                  final s = 0.96 + (pulse.value * 0.04);
                  return Transform.scale(
                    scale: s,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: night
                            ? Colors.white.withOpacity(0.10)
                            : Colors.white.withOpacity(0.65),
                        border: Border.all(
                          color: tip.accent.withOpacity(night ? 0.40 : 0.28),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: tip.accent.withOpacity(night ? 0.22 : 0.18),
                            blurRadius: 22,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(tip.icon, color: tip.accent, size: 28),
                    ),
                  );
                },
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // chip título (diferenciación visible)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: tip.accent.withOpacity(night ? 0.20 : 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: tip.accent.withOpacity(0.25),
                          ),
                        ),
                        child: Text(
                          tip.title,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: night ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        tip.message,
                        style: TextStyle(
                          fontSize: 13.4,
                          height: 1.28,
                          fontWeight: FontWeight.w600,
                          color: msgColor,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 10),

              _SoftArrow(
                night: night,
                accent: tip.accent,
              ),
            ],
          ),
        ),

        // shine diagonal
        IgnorePointer(
          child: AnimatedBuilder(
            animation: shine,
            builder: (context, _) {
              final w = MediaQuery.of(context).size.width;
              final x = (shine.value * 2.3) - 0.7;
              return Opacity(
                opacity: night ? 0.07 : 0.10,
                child: Transform.translate(
                  offset: Offset(w * x, 0),
                  child: Transform.rotate(
                    angle: -0.28,
                    child: Container(
                      width: 92,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.0),
                            Colors.white.withOpacity(0.28),
                            Colors.white.withOpacity(0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SoftArrow extends StatelessWidget {
  final bool night;
  final Color accent;

  const _SoftArrow({
    required this.night,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: night
                ? Colors.white.withOpacity(0.08)
                : Colors.white.withOpacity(0.55),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: accent.withOpacity(night ? 0.22 : 0.18),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: night
                ? Colors.white.withOpacity(0.65)
                : accent.withOpacity(0.55),
          ),
        ),
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  final int length;
  final int index;
  final bool night;

  const _DotsIndicator({
    required this.length,
    required this.index,
    required this.night,
  });

  @override
  Widget build(BuildContext context) {
    final active =
        night ? Colors.white.withOpacity(0.80) : Colors.black.withOpacity(0.45);
    final idle =
        night ? Colors.white.withOpacity(0.18) : Colors.black.withOpacity(0.12);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final isActive = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 22 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? active : idle,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}
