// lib/screens/home_screen.dart
import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../controllers/home_controller.dart';
import '../routes/app_routes.dart';

import '../widgets/notification_bell_button.dart';
import '../widgets/safety_tips_carousel.dart';
import '../widgets/safezone_nav_bar.dart';
import 'emergency_report_screen.dart';

// ✅ OFFLINE
import '../offline/offline_bootstrap.dart';
import '../offline/offline_incident.dart';
import '../offline/offline_sms_service.dart';

// ✅ API
import '../service/emergency_report_service.dart';

// ✅ CONTACTS CACHE (Hive)
import '../offline/emergency_contacts_cache.dart';

// ✅ HOME HEADER CACHE (Hive)
import '../offline/home_header_cache.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // ✅ 4 items: Home, Explorar, Comunidades, Menú
  int _currentIndex = 0;

  // ✅ Singleton: NO instanciar ni destruir
  final HomeController _controller = HomeController.instance;

  // ✅ Guardar listener para removerlo en dispose
  late final VoidCallback _controllerListener;

  // ✅ SOS anim
  late final AnimationController _sosController;

  Timer? _sosHoldTimer;
  double _sosHoldProgress = 0.0;
  bool _isHoldingSOS = false;
  static const Duration _sosHoldDuration = Duration(seconds: 3);

  bool _quickSosShown = false;

  final EmergencyReportService _svc = EmergencyReportService();
  final EmergencyContactsCache _contactsCache = EmergencyContactsCache.instance;

  // ✅ Cache "Facebook-like" para header
  final HomeHeaderCache _homeHeaderCache = HomeHeaderCache();
  String? _cachedCommunityName;
  String? _cachedLocationLabel;
  String? _cachedPhotoUrl;
  int? _cachedHeaderUpdatedAt;

  Timer? _headerSaveDebounce;

  // =========================================================
  // ✅ OFFLINE/ONLINE STATE
  // =========================================================
  bool _isOnline = true;
  bool _bootstrapped = false;
  bool _navigatedAway = false;
  StreamSubscription? _connSub;

  @override
  void initState() {
    super.initState();

    _controllerListener = () {
      if (!mounted) return;
      _scheduleSaveHeaderSnapshot();
      setState(() {});
    };
    _controller.addListener(_controllerListener);

    _sosController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);

    _bootstrap();
  }

  // =========================================================
  // BOOTSTRAP (offline-first)
  // =========================================================
  Future<void> _bootstrap() async {
    // 1) Inicializar offline + caches SIEMPRE
    try {
      await OfflineBootstrap.ensureInitialized();
    } catch (_) {}

    await _initContactsCache();
    await _initHomeHeaderCache();

    // 2) Conectividad inicial + listener
    await _refreshConnectivity();
    _listenConnectivity();

    // 3) Init del controller (puede fallar por red; NO navegue en ese caso)
    try {
      await _controller.init();
    } catch (_) {}

    if (!mounted) return;
    _bootstrapped = true;

    // 4) Routing seguro: solo navegar si estás online
    await _postInitRouting();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _refreshConnectivity() async {
    try {
      final r = await Connectivity().checkConnectivity();
      final online = r != ConnectivityResult.none;
      if (!mounted) return;
      setState(() => _isOnline = online);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isOnline = false);
    }
  }

  void _listenConnectivity() {
    _connSub?.cancel();
    _connSub = Connectivity().onConnectivityChanged.listen((r) async {
      final online = r != ConnectivityResult.none;
      if (!mounted) return;

      final changed = online != _isOnline;
      setState(() => _isOnline = online);

      if (changed && online) {
        try {
          await _controller.init(force: true);
        } catch (_) {}
        await _postInitRouting();
        if (!mounted) return;
        setState(() {});
      }
    });
  }

  /// ✅ Reglas:
  /// - OFFLINE: nunca empujes a login/picker.
  /// - ONLINE: si falta userId => login; si falta communityId => picker.
  Future<void> _postInitRouting() async {
    if (!mounted || _navigatedAway) return;
    if (!_isOnline) return;

    final st = _controller.state;

    if (st.userId == null) {
      _navigatedAway = true;
      AppRoutes.navigateAndClearStack(context, AppRoutes.login);
      return;
    }

    if (st.communityId == null) {
      _navigatedAway = true;
      AppRoutes.navigateAndClearStack(context, AppRoutes.communityPicker);
      return;
    }
  }

  Future<void> _initContactsCache() async {
    try {
      await _contactsCache.init();
    } catch (_) {}
  }

  Future<void> _initHomeHeaderCache() async {
    try {
      await _homeHeaderCache.init();
      final snap = _homeHeaderCache.read();
      if (!mounted) return;
      setState(() {
        _cachedCommunityName = snap[HomeHeaderCache.kCommunityName] as String?;
        _cachedLocationLabel = snap[HomeHeaderCache.kLocationLabel] as String?;
        _cachedPhotoUrl = snap[HomeHeaderCache.kPhotoUrl] as String?;
        _cachedHeaderUpdatedAt = snap[HomeHeaderCache.kUpdatedAt] as int?;
      });
    } catch (_) {}
  }

  void _scheduleSaveHeaderSnapshot() {
    _headerSaveDebounce?.cancel();
    _headerSaveDebounce = Timer(const Duration(milliseconds: 650), () async {
      final st = _controller.state;
      try {
        await _homeHeaderCache.init();
        await _homeHeaderCache.save(
          communityName: st.communityName,
          locationLabel: st.locationLabel,
          photoUrl: st.photoUrl,
        );
      } catch (_) {}
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_quickSosShown) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args["openQuickSos"] == true) {
      _quickSosShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showQuickSosModal();
      });
    }
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _headerSaveDebounce?.cancel();
    _sosHoldTimer?.cancel();
    _sosController.dispose();

    // ✅ crítico: remover listener del singleton
    _controller.removeListener(_controllerListener);

    super.dispose();
  }

  // =========================================================
  // ✅ NAV TAP
  // =========================================================
  void _onNavTap(int index) {
    if (index == _currentIndex && index != 3) return;

    if (index == 3) {
      final st = _controller.state;

      final String? photoUrl =
          (st.photoUrl != null && st.photoUrl!.trim().isNotEmpty)
              ? st.photoUrl!.trim()
              : _cachedPhotoUrl;

      final String displayName = _tryGetDisplayNameFromState(st) ?? "Mi cuenta";

      AppRoutes.navigateTo(
        context,
        AppRoutes.menu,
        arguments: {
          "photoUrl": photoUrl,
          "displayName": displayName,
        },
      );
      return;
    }

    setState(() => _currentIndex = index);

    switch (index) {
      case 0:
        break;
      case 1:
        AppRoutes.navigateAndReplace(context, AppRoutes.explore);
        break;
      case 2:
        AppRoutes.navigateAndReplace(context, AppRoutes.community);
        break;
    }
  }

  // =========================================================
  // Helpers Tip -> Emergency
  // =========================================================
  IconData _iconFromType(String type) {
    switch (type.toLowerCase()) {
      case "médica":
      case "medica":
        return Icons.local_hospital_outlined;
      case "fuego":
        return Icons.local_fire_department_outlined;
      case "desastre":
        return Icons.domain_outlined;
      case "accidente":
        return Icons.car_crash;
      case "violencia":
        return Icons.flash_on_outlined;
      case "robo":
        return Icons.person_off_outlined;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  Color _colorFromType(String type) {
    switch (type.toLowerCase()) {
      case "médica":
      case "medica":
        return const Color(0xFF4CC9A6);
      case "fuego":
        return const Color(0xFFFF6B6B);
      case "desastre":
        return const Color(0xFF5C9ECC);
      case "accidente":
        return const Color(0xFFB574F0);
      case "violencia":
        return const Color(0xFFF06292);
      case "robo":
        return const Color(0xFFF7D774);
      default:
        return const Color(0xFFFF5A5F);
    }
  }

  void _openEmergencyFromTip(String type) {
    final st = _controller.state;

    if (st.userId == null || st.communityId == null) {
      if (_isOnline) {
        if (st.userId == null) {
          AppRoutes.navigateAndClearStack(context, AppRoutes.login);
        } else {
          AppRoutes.navigateAndClearStack(context, AppRoutes.communityPicker);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sin internet: sesión/comunidad no disponible aún."),
          ),
        );
      }
      return;
    }

    final icon = _iconFromType(type);
    final color = _colorFromType(type);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmergencyReportScreen(
          emergencyType: type,
          icon: icon,
          colors: [color, color],
          usuarioId: st.userId,
          comunidadId: st.communityId,
          initialLat: st.currentPosition?.latitude,
          initialLng: st.currentPosition?.longitude,
          source: 'CAROUSEL_TIP',
        ),
      ),
    );
  }

  // =========================================================
  // SOS (Online/Offline)
  // =========================================================

  /// ✅ INTERNET REAL (no solo wifi/datos)
  Future<bool> _hasInternetNow() async {
    try {
      final r = await Connectivity().checkConnectivity();
      if (r == ConnectivityResult.none) return false;

      final res =
          await InternetAddress.lookup('example.com').timeout(const Duration(seconds: 3));

      return res.isNotEmpty && res.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> _loadCachedEmergencyPhones() async {
    try {
      await _contactsCache.init();
      return _contactsCache.getPhones();
    } catch (_) {
      return <String>[];
    }
  }

  String _buildSosDescripcion() => "[SOS DIRECTO] Alerta SOS enviada desde Home.";

  Future<void> _sendSosReport() async {
    final st = _controller.state;

    final uid = st.userId;
    final cid = st.communityId;

    if (uid == null || cid == null) {
      if (_isOnline) {
        if (uid == null) {
          AppRoutes.navigateAndClearStack(context, AppRoutes.login);
        } else {
          AppRoutes.navigateAndClearStack(context, AppRoutes.communityPicker);
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sin internet: no se pudo validar sesión/comunidad."),
          ),
        );
      }
      return;
    }

    final lat = st.currentPosition?.latitude;
    final lng = st.currentPosition?.longitude;

    const tipo = "SOS_GENERAL";
    const prioridad = "ALTA";
    final descripcion = _buildSosDescripcion();

    final clientId = const Uuid().v4();

    // OFFLINE (internet real)
    if (!await _hasInternetNow()) {
      bool smsSent = false;
      String canalEnvio = "OFFLINE_QUEUE";

      try {
        final phones = await _loadCachedEmergencyPhones();

        if (phones.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("No tienes contactos de emergencia guardados para modo offline."),
            ),
          );
          return;
        }

        final msg = (lat != null && lng != null)
            ? "SAFEZONE SOS\nID:$clientId\n$descripcion\nUbicación: https://maps.google.com/?q=$lat,$lng"
            : "SAFEZONE SOS\nID:$clientId\n$descripcion\nUbicación: (no disponible)";

        // ✅ usa resultado detallado (y si tu Android bloquea SmsManager, el service hace fallback)
        final smsRes = await OfflineSmsService().sendSmsToManyDetailed(
          phones: phones,
          message: msg,
        );

        smsSent = smsRes.anyOk;
        canalEnvio = smsSent ? "OFFLINE_SMS" : "OFFLINE_QUEUE";

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(smsRes.uiMessage()),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } catch (_) {
        canalEnvio = "OFFLINE_QUEUE";
      }

      final item = OfflineIncident(
        clientGeneratedId: clientId,
        tipo: tipo,
        descripcion: descripcion,
        nivelPrioridad: prioridad,
        usuarioId: uid,
        comunidadId: cid,
        lat: lat,
        lng: lng,
        localImagePath: null,
        localVideoPath: null,
        localAudioPath: null,
        ai: null,
        canalEnvio: canalEnvio,
        smsEnviadoPorCliente: smsSent,
        createdAtMillis: DateTime.now().millisecondsSinceEpoch,
      );

      await OfflineBootstrap.queue.enqueue(item);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Sin internet: SOS guardado y se enviará al volver conexión. "
            "SMS: ${smsSent ? "Listo" : "Pendiente"} | "
            "Pendientes: ${OfflineBootstrap.queue.count()}",
          ),
        ),
      );
      return;
    }

    // ONLINE
    try {
      final incidenteId = await _svc.createIncident(
        tipo: tipo,
        descripcion: descripcion,
        nivelPrioridad: prioridad,
        usuarioId: uid,
        comunidadId: cid,
        lat: lat,
        lng: lng,
        imagenUrl: null,
        videoUrl: null,
        audioUrl: null,
        ai: null,
        clientGeneratedId: clientId,
        canalEnvio: "ONLINE",
        smsEnviadoPorCliente: false,
      );

      await _svc.postIncidentToChat(
        usuarioId: uid,
        comunidadId: cid,
        canal: "COMUNIDAD",
        descripcion: descripcion,
        incidenteId: incidenteId,
        imagenUrl: null,
        videoUrl: null,
        audioUrl: null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("SOS enviado y publicado en la comunidad")),
      );
    } catch (_) {
      final item = OfflineIncident(
        clientGeneratedId: clientId,
        tipo: tipo,
        descripcion: descripcion,
        nivelPrioridad: prioridad,
        usuarioId: uid,
        comunidadId: cid,
        lat: lat,
        lng: lng,
        localImagePath: null,
        localVideoPath: null,
        localAudioPath: null,
        ai: null,
        canalEnvio: "OFFLINE_QUEUE",
        smsEnviadoPorCliente: false,
        createdAtMillis: DateTime.now().millisecondsSinceEpoch,
      );
      await OfflineBootstrap.queue.enqueue(item);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Error enviando SOS (se guardó offline). Pendientes: ${OfflineBootstrap.queue.count()}",
          ),
        ),
      );
    }
  }

  void _startSosHold() {
    if (_isHoldingSOS) return;

    _sosHoldTimer?.cancel();
    setState(() {
      _isHoldingSOS = true;
      _sosHoldProgress = 0.0;
    });

    const tickMs = 40;
    int elapsed = 0;

    _sosHoldTimer = Timer.periodic(
      const Duration(milliseconds: tickMs),
      (t) async {
        elapsed += tickMs;

        if (!mounted) {
          t.cancel();
          return;
        }

        final p = elapsed / _sosHoldDuration.inMilliseconds;
        setState(() => _sosHoldProgress = p.clamp(0.0, 1.0));

        if (elapsed >= _sosHoldDuration.inMilliseconds) {
          t.cancel();
          if (!mounted) return;

          setState(() {
            _isHoldingSOS = false;
            _sosHoldProgress = 1.0;
          });

          await _sendSosReport();

          if (!mounted) return;
          setState(() => _sosHoldProgress = 0.0);
        }
      },
    );
  }

  void _cancelSosHold() {
    _sosHoldTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isHoldingSOS = false;
      _sosHoldProgress = 0.0;
    });
  }

  Future<void> _showQuickSosModal() async {
    final bool night = Theme.of(context).brightness == Brightness.dark;

    bool isHolding = false;
    double progress = 0.0;
    Timer? timer;
    bool dialogOpen = true;

    const Duration holdDuration = Duration(seconds: 2);
    const int tickMs = 40;

    void startHold(StateSetter setModalState, BuildContext dialogContext) {
      if (isHolding) return;

      isHolding = true;
      progress = 0.0;
      setModalState(() {});

      int elapsed = 0;
      timer?.cancel();

      timer = Timer.periodic(const Duration(milliseconds: tickMs), (t) async {
        if (!dialogOpen) {
          t.cancel();
          return;
        }

        elapsed += tickMs;
        progress = (elapsed / holdDuration.inMilliseconds).clamp(0.0, 1.0);
        setModalState(() {});

        if (elapsed >= holdDuration.inMilliseconds) {
          t.cancel();
          await _sendSosReport();

          if (dialogOpen && Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop();
          }
        }
      });
    }

    void cancelHold(StateSetter setModalState) {
      timer?.cancel();
      isHolding = false;
      progress = 0.0;
      setModalState(() {});
    }

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setModalState) {
            return AlertDialog(
              backgroundColor: night ? const Color(0xFF0B1016) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5A5F)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "SOS rápido",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Vas a enviar una alerta SOS a tu red.\n"
                    "Para evitar falsos positivos, confirma manteniendo presionado.",
                    style: TextStyle(
                      color: night ? Colors.white70 : Colors.black87,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onLongPressStart: (_) =>
                        startHold(setModalState, dialogContext),
                    onLongPressEnd: (_) => cancelHold(setModalState),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Color(0xFFFFA07A),
                                Color(0xFFFF5A5F),
                                Color(0xFFE53935),
                              ],
                              center: Alignment(-0.2, -0.3),
                              radius: 0.95,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "SOS",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isHolding ? "Enviando…" : "Mantén 2s",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isHolding || progress > 0)
                          SizedBox(
                            width: 136,
                            height: 136,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 6,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withOpacity(0.95),
                              ),
                              backgroundColor:
                                  Colors.white.withOpacity(0.15),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text("Cancelar"),
                ),
              ],
            );
          },
        );
      },
    );

    dialogOpen = false;
    timer?.cancel();
  }

  // =========================================================
  // UI
  // =========================================================
  @override
  Widget build(BuildContext context) {
    final st = _controller.state;
    final bool night = Theme.of(context).brightness == Brightness.dark;

    final String headerCommunityName =
        (st.communityName != null && st.communityName!.trim().isNotEmpty)
            ? st.communityName!
            : (_cachedCommunityName ?? "Sin comunidad");

    final String headerLocationLabel = (st.locationLabel.trim().isNotEmpty)
        ? st.locationLabel
        : (_cachedLocationLabel ?? "Ubicación no disponible");

    final String? headerPhotoUrl =
        (st.photoUrl != null && st.photoUrl!.trim().isNotEmpty)
            ? st.photoUrl
            : _cachedPhotoUrl;

    final Color scaffoldBg =
        night ? const Color(0xFF050509) : const Color(0xFFFDF7F7);
    final Color cardBg = night ? const Color(0xFF13151D) : Colors.white;
    final Color cardText = night ? Colors.white : const Color(0xFF222222);
    final Color subtleText = night ? Colors.white70 : Colors.grey.shade700;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),

                // ✅ Banner offline/online
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: _isOnline ? 0 : 36,
                    curve: Curves.easeOut,
                    child: _isOnline
                        ? const SizedBox.shrink()
                        : Container(
                            decoration: BoxDecoration(
                              color: night
                                  ? const Color(0xFF2A1B1B)
                                  : const Color(0xFFFFECEC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    const Color(0xFFFF5A5F).withOpacity(0.35),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.wifi_off,
                                    size: 16, color: Color(0xFFFF5A5F)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Sin internet: usando datos guardados. Se sincronizará al volver la conexión.",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: night
                                          ? Colors.white70
                                          : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 8),

                // ✅ Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: night ? const Color(0xFF181A24) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(night ? 0.45 : 0.12),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () =>
                              AppRoutes.navigateTo(context, AppRoutes.profile),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFFF5A5F),
                                width: 2,
                              ),
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withOpacity(night ? 0.5 : 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: (headerPhotoUrl != null &&
                                      headerPhotoUrl.trim().isNotEmpty)
                                  ? Image.network(
                                      headerPhotoUrl,
                                      fit: BoxFit.cover,
                                      gaplessPlayback: true,
                                      loadingBuilder:
                                          (context, child, progress) {
                                        if (progress == null) return child;
                                        return const Icon(
                                          Icons.person,
                                          size: 22,
                                          color: Color(0xFFFF5A5F),
                                        );
                                      },
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.person,
                                        size: 22,
                                        color: Color(0xFFFF5A5F),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person,
                                      size: 22,
                                      color: Color(0xFFFF5A5F),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                headerCommunityName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: cardText,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.location_on,
                                      size: 14, color: Color(0xFFFF5A5F)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      headerLocationLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: subtleText,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (_cachedHeaderUpdatedAt != null &&
                                  (st.communityName == null ||
                                      st.communityName!.isEmpty))
                                Text(
                                  "Última carga: ${DateTime.fromMillisecondsSinceEpoch(_cachedHeaderUpdatedAt!).toLocal()}",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: subtleText.withOpacity(0.8),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        NotificationBellButton(
                          night: night,
                          comunidadId: st.communityId,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ✅ Body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SafetyTipsCarousel(
                          nightMode: night,
                          onTipTap: (tip) => _openEmergencyFromTip(tip.title),
                        ),
                        const SizedBox(height: 22),

                        // ✅ SOS Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(18, 22, 18, 26),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withOpacity(night ? 0.4 : 0.10),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              GestureDetector(
                                onLongPressStart: (_) => _startSosHold(),
                                onLongPressEnd: (_) => _cancelSosHold(),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    AnimatedBuilder(
                                      animation: _sosController,
                                      builder: (context, child) {
                                        final scale = 1 +
                                            0.06 *
                                                (_sosController.value - 0.5)
                                                    .abs() *
                                                2;
                                        return Transform.scale(
                                          scale: scale,
                                          child: child,
                                        );
                                      },
                                      child: Container(
                                        width: 170,
                                        height: 170,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: RadialGradient(
                                            colors: [
                                              Color(0xFFFFA07A),
                                              Color(0xFFFF5A5F),
                                              Color(0xFFE53935),
                                            ],
                                            center: Alignment(-0.2, -0.3),
                                            radius: 0.95,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Color(0x66FF5A5F),
                                              blurRadius: 30,
                                              spreadRadius: 10,
                                              offset: Offset(0, 12),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Text(
                                              "SOS",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 34,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _isHoldingSOS
                                                  ? "Enviando…"
                                                  : "Mantén 3 segundos",
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (_isHoldingSOS || _sosHoldProgress > 0)
                                      SizedBox(
                                        width: 190,
                                        height: 190,
                                        child: CircularProgressIndicator(
                                          value: _sosHoldProgress,
                                          strokeWidth: 6,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.white.withOpacity(0.95),
                                          ),
                                          backgroundColor:
                                              Colors.white.withOpacity(0.15),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "Mantén presionado para enviar una alerta a tu red.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: subtleText,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                        Text(
                          "¿Cuál es tu emergencia?",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: cardText,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildEmergencyChips(night),

                        const SizedBox(height: 110),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ✅ Nav
          SafeZoneNavBar(
            currentIndex: _currentIndex,
            isNightMode: night,
            onTap: _onNavTap,
            photoUrl: headerPhotoUrl,
            bottomExtra: 0,
          ),

          // ✅ overlay de carga al arrancar
          if (!_bootstrapped)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: Container(
                  color: Colors.black.withOpacity(night ? 0.55 : 0.20),
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: night ? const Color(0xFF13151D) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _isOnline ? "Cargando…" : "Cargando (offline)…",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: night ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // =========================================================
  // Utils
  // =========================================================
  String? _tryGetDisplayNameFromState(dynamic st) {
    try {
      final v1 = (st.displayName ?? '') as String?;
      if (v1 != null && v1.trim().isNotEmpty) return v1.trim();
    } catch (_) {}
    try {
      final v2 = (st.nombre ?? '') as String?;
      if (v2 != null && v2.trim().isNotEmpty) return v2.trim();
    } catch (_) {}
    try {
      final v3 = (st.name ?? '') as String?;
      if (v3 != null && v3.trim().isNotEmpty) return v3.trim();
    } catch (_) {}
    return null;
  }

  Widget _buildEmergencyChips(bool night) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _chip("Médica", Icons.local_hospital_outlined,
            const Color(0xFF4CC9A6), night),
        _chip("Fuego", Icons.local_fire_department_outlined,
            const Color(0xFFFF6B6B), night),
        _chip("Desastre", Icons.domain_outlined,
            const Color(0xFF5C9ECC), night),
        _chip("Accidente", Icons.car_crash, const Color(0xFFB574F0), night),
        _chip("Violencia", Icons.flash_on_outlined,
            const Color(0xFFF06292), night),
        _chip("Robo", Icons.person_off_outlined,
            const Color(0xFFF7D774), night),
      ],
    );
  }

  Widget _chip(String text, IconData icon, Color color, bool night) {
    return GestureDetector(
      onTap: () => _handleEmergencyType(text, icon, [color, color]),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: night ? const Color(0xFF181A24) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withOpacity(0.65), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(night ? 0.45 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: night ? Colors.white : const Color(0xFF222222),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleEmergencyType(String type, IconData icon, List<Color> colors) {
    final st = _controller.state;

    if (st.userId == null || st.communityId == null) {
      if (_isOnline) {
        if (st.userId == null) {
          AppRoutes.navigateAndClearStack(context, AppRoutes.login);
        } else {
          AppRoutes.navigateAndClearStack(context, AppRoutes.communityPicker);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sin internet: sesión/comunidad no disponible aún."),
          ),
        );
      }
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmergencyReportScreen(
          emergencyType: type,
          icon: icon,
          colors: colors,
          usuarioId: st.userId,
          comunidadId: st.communityId,
          initialLat: st.currentPosition?.latitude,
          initialLng: st.currentPosition?.longitude,
          source: 'BOTON_EMERGENCIA',
        ),
      ),
    );
  }
}
