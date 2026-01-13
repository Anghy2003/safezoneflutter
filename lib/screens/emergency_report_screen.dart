// lib/screens/emergency_report_screen.dart
import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../offline/emergency_contacts_cache.dart';
import '../offline/offline_bootstrap.dart';
import '../offline/offline_incident.dart';
import '../offline/offline_sms_service.dart';
import '../routes/app_routes.dart';
import '../service/auth_service.dart';
import '../service/cloudinary_service.dart';
import '../service/emergency_report_service.dart';
import 'ai_chat_screen.dart';

class EmergencyReportScreen extends StatefulWidget {
  final String emergencyType;
  final IconData icon;
  final List<Color> colors;

  final int? usuarioId;
  final int? comunidadId;
  final double? initialLat;
  final double? initialLng;
  final String? source;

  const EmergencyReportScreen({
    super.key,
    required this.emergencyType,
    required this.icon,
    required this.colors,
    this.usuarioId,
    this.comunidadId,
    this.initialLat,
    this.initialLng,
    this.source,
  });

  @override
  State<EmergencyReportScreen> createState() => _EmergencyReportScreenState();
}

class _EmergencyReportScreenState extends State<EmergencyReportScreen>
    with SingleTickerProviderStateMixin {
  final _svc = EmergencyReportService();

  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  late final AnimationController _aiPulse;

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _attachedImages = [];
  final List<XFile> _attachedVideos = [];

  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _hasAudio = false;
  bool _isRecording = false;
  File? _audioFile;

  Position? _attachedLocation;

  int? _resolvedUsuarioId;
  int? _resolvedComunidadId;

  Timer? _holdTimer;
  double _holdProgress = 0.0;
  bool _isHolding = false;
  static const Duration _holdDuration = Duration(seconds: 3);

  final _contactsCache = EmergencyContactsCache.instance;

  // ==========================
  // ✅ ECU 911 (SAFE FLAG)
  // ==========================
  static const bool _enableEcu911 = bool.fromEnvironment(
    'ENABLE_ECU911',
    defaultValue: false,
  );

  bool get _isNightMode => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();

    // 🔒 reconstruye sesión (prefs + headers) sin bloquear UI
    AuthService.restoreSession();

    // ✅ offline bootstrap + cache contactos
    OfflineBootstrap.ensureInitialized();
    _contactsCache.init();

    _aiPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
      lowerBound: 0.985,
      upperBound: 1.02,
    )..repeat(reverse: true);

    _resolveIds();
  }

  Future<void> _resolveIds() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = widget.usuarioId ?? prefs.getInt("userId");
    final cid = widget.comunidadId ??
        prefs.getInt("comunidadId") ??
        prefs.getInt("communityId");

    if (!mounted) return;
    setState(() {
      _resolvedUsuarioId = uid;
      _resolvedComunidadId = cid;
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _aiPulse.dispose();
    _messageController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  // =====================================================
  // HOLD BUTTON (BOTÓN DE EMERGENCIA)
  // =====================================================
  void _startHoldToSend() {
    if (_isSending) return;

    _holdTimer?.cancel();
    setState(() {
      _isHolding = true;
      _holdProgress = 0.0;
    });

    const tickMs = 40;
    int elapsed = 0;

    _holdTimer = Timer.periodic(const Duration(milliseconds: tickMs), (t) async {
      elapsed += tickMs;
      final p = elapsed / _holdDuration.inMilliseconds;

      if (!mounted) {
        t.cancel();
        return;
      }

      setState(() => _holdProgress = p.clamp(0.0, 1.0));

      if (elapsed >= _holdDuration.inMilliseconds) {
        t.cancel();
        if (!mounted) return;

        setState(() {
          _isHolding = false;
          _holdProgress = 1.0;
        });

        // ✅ SMART: online backend o offline SMS DIRECTO + cola
        await _sendEmergencySmart(direct: true);

        if (!mounted) return;
        setState(() => _holdProgress = 0.0);
      }
    });
  }

  void _cancelHoldToSend() {
    _holdTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isHolding = false;
      _holdProgress = 0.0;
    });
  }

  // =====================================================
  // ✅ ECU 911
  // =====================================================
  Future<void> _confirmAndCallEcu911() async {
    if (!mounted) return;

    if (!_enableEcu911) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("ECU 911 deshabilitado en este build. (ENABLE_ECU911=false)"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Expanded(child: Text("Derivar al ECU 911")),
          ],
        ),
        content: const Text(
          "Vas a abrir el marcador del teléfono para llamar al 911.\n\n"
          "Usa esto solo si la situación es crítica y requiere atención inmediata.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Llamar 911"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final uri = Uri(scheme: 'tel', path: '911');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No se pudo abrir el marcador."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildEcu911EscalationCard({
    required Color cardColor,
    required Color cardShadow,
    required Color primaryText,
    required Color secondaryText,
  }) {
    final disabled = !_enableEcu911;
    final border = _isNightMode
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.06);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: cardShadow,
            blurRadius: 18,
            offset: const Offset(0, 10),
          )
        ],
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.redAccent.withOpacity(disabled ? 0.18 : 0.22),
              border: Border.all(
                color: Colors.redAccent.withOpacity(disabled ? 0.25 : 0.35),
              ),
            ),
            child: Icon(
              Icons.phone_in_talk_rounded,
              color: Colors.redAccent.withOpacity(disabled ? 0.55 : 1.0),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Caso muy grave: Derivar al ECU 911",
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  disabled
                      ? "Deshabilitado por defecto para evitar llamadas accidentales. Habilítalo solo en pruebas autorizadas."
                      : "Abrirá el marcador con 911. Úsalo únicamente si requiere atención inmediata.",
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 12.2,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isSending ? null : _confirmAndCallEcu911,
                    icon: const Icon(Icons.call_rounded),
                    label: Text(disabled ? "Derivar (solo pruebas)" : "Derivar al 911"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      side: BorderSide(
                        color: Colors.redAccent.withOpacity(disabled ? 0.35 : 0.70),
                      ),
                      foregroundColor:
                          Colors.redAccent.withOpacity(disabled ? 0.6 : 1.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // ✅ SMART SEND (ONLINE vs OFFLINE)
  // =====================================================
  Future<void> _sendEmergencySmart({required bool direct}) async {
    if (_isSending) return;

    final msg = _messageController.text.trim();
    final nothing = msg.isEmpty &&
        _attachedLocation == null &&
        _attachedImages.isEmpty &&
        _attachedVideos.isEmpty &&
        !_hasAudio &&
        (widget.initialLat == null || widget.initialLng == null);

    if (nothing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Describe algo o adjunta evidencia / ubicación."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await _resolveIds();
    if (_resolvedUsuarioId == null || _resolvedComunidadId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No se pudo resolver usuario/comunidad."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Si estaba grabando, detén antes de enviar
    if (_isRecording) {
      final stopPath = await _audioRecorder.stop();
      if (stopPath != null) {
        _audioFile = File(stopPath);
        _hasAudio = true;
      }
      _isRecording = false;
    }

    setState(() => _isSending = true);

    final clientId = const Uuid().v4();

    try {
      // ✅ usa la MISMA lógica que Home: "internet real"
      if (await _hasInternetNow()) {
        await _sendEmergencyOnline(direct: direct, clientId: clientId);
      } else {
        // ✅ OFFLINE: SMS (si se puede) + cola offline
        await _sendEmergencyOfflineSmsAndQueue(direct: direct, clientId: clientId);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error enviando reporte: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // =====================================================
  // ✅ ONLINE: backend + chat
  // =====================================================
  Future<void> _sendEmergencyOnline({
    required bool direct,
    required String clientId,
  }) async {
    final msg = _messageController.text.trim();

    final baseDescripcion = msg.isNotEmpty ? msg : "Reporte: ${widget.emergencyType}.";
    final descripcion = direct ? "[SOS DIRECTO] $baseDescripcion" : baseDescripcion;

    final ll = await _resolveLatLngIfNeeded();
    final latToSend = ll?.lat;
    final lngToSend = ll?.lng;

    String? imagenUrl;
    String? videoUrl;
    String? videoThumbUrl;
    String? audioUrl;

    if (_attachedImages.isNotEmpty) {
      imagenUrl = await CloudinaryService.uploadImage(File(_attachedImages.first.path));
    }

    if (_attachedVideos.isNotEmpty) {
      final file = File(_attachedVideos.first.path);
      videoUrl = await CloudinaryService.uploadVideo(file);
      videoThumbUrl = await _generateVideoThumbnailUrl(file.path);
    }

    if (_hasAudio && _audioFile != null) {
      audioUrl = await CloudinaryService.uploadAudio(_audioFile!);
    }

    AiAnalysisResult? ai;
    String tipoToSend;
    String prioridadToSend;

    if (direct) {
      tipoToSend = _svc.buildSosTipo(widget.emergencyType);
      prioridadToSend = "ALTA";
    } else {
      final aiRaw = await _svc.analyzeWithIA(
        descripcion: descripcion,
        usuarioId: _resolvedUsuarioId,
        imagenUrl: imagenUrl,
        videoThumbUrl: videoThumbUrl,
        audioTranscripcion: null,
      );

      ai = AiAnalysisResult.fromJson(aiRaw, fallbackCategory: widget.emergencyType);

      if (_svc.shouldBlockPublish(possibleFake: ai.possibleFake, priority: ai.priority)) {
        await _showBlockedDialog(ai: ai);
        return;
      }

      tipoToSend = ai.category;
      prioridadToSend = ai.priority;
    }

    final incidenteId = await _svc.createIncident(
      tipo: tipoToSend,
      descripcion: descripcion,
      nivelPrioridad: prioridadToSend,
      usuarioId: _resolvedUsuarioId!,
      comunidadId: _resolvedComunidadId!,
      lat: latToSend,
      lng: lngToSend,
      imagenUrl: imagenUrl,
      videoUrl: videoUrl,
      audioUrl: audioUrl,
      ai: ai,
      clientGeneratedId: clientId,
      canalEnvio: "ONLINE",
      smsEnviadoPorCliente: false,
    );

    final canal = _svc.resolveChatCanal(widget.source);
    await _svc.postIncidentToChat(
      usuarioId: _resolvedUsuarioId!,
      comunidadId: _resolvedComunidadId!,
      canal: canal,
      descripcion: descripcion,
      incidenteId: incidenteId,
      imagenUrl: imagenUrl,
      videoUrl: videoUrl,
      audioUrl: audioUrl,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 28),
            const SizedBox(width: 10),
            const Text("Enviado"),
          ],
        ),
        content: Text(
          direct
              ? "Reporte enviado en modo DIRECTO (sin IA).\nTipo: $tipoToSend\nPrioridad: $prioridadToSend"
              : "Clasificación IA:\nTipo: ${ai!.category}\nPrioridad: ${ai.priority}\nPosible Falso: ${ai.possibleFake ? "Sí" : "No"}",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.explore,
                (route) => false,
                arguments: {"incidenteId": incidenteId, "focus": true},
              );
            },
            child: const Text("Ver en el mapa"),
          ),
        ],
      ),
    );

    _messageController.clear();
    _clearAttachments();
  }

  // =====================================================
  // ✅ OFFLINE: SMS (igual Home) + COLA OFFLINE
  // =====================================================
  Future<void> _sendEmergencyOfflineSmsAndQueue({
    required bool direct,
    required String clientId,
  }) async {
    final msg = _messageController.text.trim();

    final baseDescripcion = msg.isNotEmpty ? msg : "Reporte: ${widget.emergencyType}.";
    final descripcion = direct ? "[SOS DIRECTO] $baseDescripcion" : baseDescripcion;

    final ll = await _resolveLatLngIfNeeded();
    final latToSend = ll?.lat;
    final lngToSend = ll?.lng;

    final tipoOffline = direct ? _svc.buildSosTipo(widget.emergencyType) : widget.emergencyType;
    final prioOffline = direct ? "ALTA" : "MEDIA";

    // 1) teléfonos desde Hive
    final phones = await _loadCachedEmergencyPhones();
    if (phones.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No tienes contactos de emergencia guardados offline."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 2) mensaje SMS
    final smsMsg = _buildOfflineSmsMessage(
      tipo: tipoOffline,
      descripcion: descripcion,
      lat: latToSend,
      lng: lngToSend,
      clientId: clientId,
    );

    // 3) enviar SMS con el MISMO servicio del Home (maneja permisos/capacidad/fallback)
    bool smsSent = false;
    String smsUiMessage = "SMS pendiente.";

    try {
      final smsRes = await OfflineSmsService().sendSmsToManyDetailed(
        phones: phones,
        message: smsMsg,
      );
      smsSent = smsRes.anyOk;
      smsUiMessage = smsRes.uiMessage();
    } catch (_) {
      smsSent = false;
      smsUiMessage = "No se pudo enviar SMS (permiso/capacidad). Se guardó en cola.";
    }

    // 4) encolar offline (para sincronizar con backend luego)
    await _enqueueOfflineOnly(
      clientId: clientId,
      tipo: tipoOffline,
      descripcion: descripcion,
      prioridad: prioOffline,
      usuarioId: _resolvedUsuarioId!,
      comunidadId: _resolvedComunidadId!,
      lat: latToSend,
      lng: lngToSend,
      smsSentByClient: smsSent,
    );

    int? pending;
    try {
      pending = OfflineBootstrap.queue.count();
    } catch (_) {
      pending = null;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(
              smsSent ? Icons.sms : Icons.wifi_off,
              color: smsSent ? Colors.green.shade700 : Colors.orange.shade700,
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(smsSent ? "SMS procesado" : "Guardado sin internet")),
          ],
        ),
        content: Text(
          "Tu reporte se guardó en el teléfono y se sincronizará cuando vuelva el internet.\n\n"
          "$smsUiMessage\n"
          "Cola pendiente: ${pending ?? "-"}",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (route) => false);
            },
            child: const Text("Entendido"),
          ),
        ],
      ),
    );

    _messageController.clear();
    _clearAttachments();
  }

  // =====================================================
  // OFFLINE HELPERS
  // =====================================================

  /// ✅ INTERNET REAL (igual Home): no confíes solo en Connectivity
  Future<bool> _hasInternetNow() async {
    try {
      final r = await Connectivity().checkConnectivity();
      if (r == ConnectivityResult.none) return false;

      final res = await InternetAddress.lookup('example.com').timeout(const Duration(seconds: 3));
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

  Future<String?> _persistToOfflineMedia(String path, String prefix) async {
    try {
      final f = File(path);
      if (!f.existsSync()) return null;

      final dir = await getApplicationDocumentsDirectory();
      final offlineDir = Directory("${dir.path}/offline_media");
      if (!offlineDir.existsSync()) offlineDir.createSync(recursive: true);

      final ext = path.contains('.') ? path.split('.').last : '';
      final out =
          "${offlineDir.path}/$prefix${DateTime.now().millisecondsSinceEpoch}${ext.isEmpty ? '' : '.$ext'}";

      await f.copy(out);
      return out;
    } catch (_) {
      return null;
    }
  }

  String _buildOfflineSmsMessage({
    required String tipo,
    required String descripcion,
    required double? lat,
    required double? lng,
    required String clientId,
  }) {
    final loc = (lat != null && lng != null)
        ? "Ubicación: https://maps.google.com/?q=$lat,$lng"
        : "Ubicación: (no disponible)";
    return "SAFEZONE ALERTA\nID:$clientId\nTipo: $tipo\n$descripcion\n$loc";
  }

  /// ✅ SOLO encola (NO manda SMS aquí)
  Future<void> _enqueueOfflineOnly({
    required String clientId,
    required String tipo,
    required String descripcion,
    required String prioridad,
    required int usuarioId,
    required int comunidadId,
    required double? lat,
    required double? lng,
    required bool smsSentByClient,
  }) async {
    String? imgPath;
    String? vidPath;
    String? audPath;

    if (_attachedImages.isNotEmpty) {
      imgPath = await _persistToOfflineMedia(_attachedImages.first.path, "img_");
    }
    if (_attachedVideos.isNotEmpty) {
      vidPath = await _persistToOfflineMedia(_attachedVideos.first.path, "vid_");
    }
    if (_hasAudio && _audioFile != null) {
      audPath = await _persistToOfflineMedia(_audioFile!.path, "aud_");
    }

    final canalEnvio = smsSentByClient ? "OFFLINE_SMS" : "OFFLINE_QUEUE";

    final item = OfflineIncident(
      clientGeneratedId: clientId,
      tipo: tipo,
      descripcion: descripcion,
      nivelPrioridad: prioridad,
      usuarioId: usuarioId,
      comunidadId: comunidadId,
      lat: lat,
      lng: lng,
      localImagePath: imgPath,
      localVideoPath: vidPath,
      localAudioPath: audPath,
      ai: null,
      canalEnvio: canalEnvio,
      smsEnviadoPorCliente: smsSentByClient,
      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
    );

    await OfflineBootstrap.queue.enqueue(item);
  }

  Future<({double lat, double lng})?> _resolveLatLngIfNeeded() async {
    if (_attachedLocation != null) {
      return (lat: _attachedLocation!.latitude, lng: _attachedLocation!.longitude);
    }
    if (widget.initialLat != null && widget.initialLng != null) {
      return (lat: widget.initialLat!, lng: widget.initialLng!);
    }

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return null;

      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return (lat: p.latitude, lng: p.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _generateVideoThumbnailUrl(String videoPath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.PNG,
        quality: 85,
      );
      if (thumbPath == null) return null;
      return await CloudinaryService.uploadImage(File(thumbPath));
    } catch (_) {
      return null;
    }
  }

  Future<void> _showBlockedDialog({required AiAnalysisResult ai}) async {
    if (!mounted) return;

    final reasonsText =
        ai.reasons.isEmpty ? "" : "\n\nMotivos:\n- ${ai.reasons.take(3).join("\n- ")}";

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange.shade700, size: 28),
            const SizedBox(width: 10),
            const Expanded(child: Text("Reporte en revisión")),
          ],
        ),
        content: Text(
          "La IA detectó que este reporte podría ser falso o de baja prioridad.\n\n"
          "Tipo: ${ai.category}\n"
          "Prioridad: ${ai.priority}\n"
          "Posible falso: ${ai.possibleFake ? "Sí" : "No"}"
          "$reasonsText\n\n"
          "No se publicará en el mapa ni se enviará al chat.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Entendido"),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomPadding = media.padding.bottom;

    final Color bgColor =
        _isNightMode ? const Color(0xFF05070A) : const Color(0xFFF3F4F6);
    final Color cardColor =
        _isNightMode ? const Color(0xFF0B1016) : Colors.white;
    final Color primaryText =
        _isNightMode ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
    final Color secondaryText =
        _isNightMode ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final Color mutedText =
        _isNightMode ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);
    final Color cardShadow =
        _isNightMode ? Colors.black.withOpacity(0.70) : Colors.black.withOpacity(0.07);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: bgColor)),
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [widget.colors.first.withOpacity(0.25), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [widget.colors.last.withOpacity(0.22), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: media.size.height * 0.32,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    widget.colors.first.withOpacity(0.90),
                    widget.colors.last.withOpacity(0.70),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Column(
                      children: [
                        _buildBanner(cardColor, cardShadow, primaryText, secondaryText),
                        const SizedBox(height: 16),
                        _buildHoldBubbleCard(
                          cardColor: cardColor,
                          cardShadow: cardShadow,
                          secondaryText: secondaryText,
                        ),
                        const SizedBox(height: 12),
                        _buildEcu911EscalationCard(
                          cardColor: cardColor,
                          cardShadow: cardShadow,
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                        ),
                        const SizedBox(height: 16),
                        _buildMessageCard(
                          cardColor: cardColor,
                          cardShadow: cardShadow,
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                          mutedText: mutedText,
                          bottomPadding: bottomPadding,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => AppRoutes.goBack(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.5)),
              ),
              child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Reporte de emergencia",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: widget.colors),
                      boxShadow: [
                        BoxShadow(
                          color: widget.colors.last.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(widget.icon, size: 12, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.emergencyType,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  "SafeZone",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner(
    Color cardColor,
    Color cardShadow,
    Color primaryText,
    Color secondaryText,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: cardShadow, blurRadius: 18, offset: const Offset(0, 10))],
        border: Border.all(
          color: _isNightMode ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.85),
          width: 1.4,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Comunica tu\nemergencia",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: primaryText,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Describe lo que ocurre para alertar a tu comunidad y a los servicios de ayuda.",
                  style: TextStyle(fontSize: 13, color: secondaryText, height: 1.25),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Image.asset(
            'assets/images/emergency_illustration.png',
            width: 98,
            height: 98,
          ),
        ],
      ),
    );
  }

  Widget _buildHoldBubbleCard({
    required Color cardColor,
    required Color cardShadow,
    required Color secondaryText,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: cardShadow, blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          GestureDetector(
            onLongPressStart: (_) => _startHoldToSend(),
            onLongPressEnd: (_) => _cancelHoldToSend(),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 136,
                  height: 136,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: widget.colors),
                    boxShadow: [
                      BoxShadow(
                        color: widget.colors.last.withOpacity(0.45),
                        blurRadius: 26,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(child: Icon(widget.icon, color: Colors.white, size: 44)),
                ),
                if (_isHolding || _holdProgress > 0)
                  SizedBox(
                    width: 152,
                    height: 152,
                    child: CircularProgressIndicator(
                      value: _holdProgress,
                      strokeWidth: 6,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.95)),
                      backgroundColor: Colors.white.withOpacity(0.12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _isHolding ? "Enviando…" : "Mantén presionado 3s",
            style: TextStyle(
              color: secondaryText,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Si NO hay internet, se intenta enviar SMS automático y se guarda en cola.",
            style: TextStyle(
              color: secondaryText.withOpacity(0.85),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard({
    required Color cardColor,
    required Color cardShadow,
    required Color primaryText,
    required Color secondaryText,
    required Color mutedText,
    required double bottomPadding,
  }) {
    final border =
        _isNightMode ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: cardShadow, blurRadius: 18, offset: const Offset(0, 10))],
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _ComposerTextField(
              controller: _messageController,
              night: _isNightMode,
              primaryText: primaryText,
              mutedText: mutedText,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _hasAnyAttachment
                  ? _AttachmentStrip(
                      key: const ValueKey("strip"),
                      night: _isNightMode,
                      secondaryText: secondaryText,
                      primaryText: primaryText,
                      imagesCount: _attachedImages.length,
                      videosCount: _attachedVideos.length,
                      hasAudio: _hasAudio,
                      hasLocation: _attachedLocation != null ||
                          (widget.initialLat != null && widget.initialLng != null),
                      onClear: _clearAttachments,
                    )
                  : _AttachmentHintMini(
                      key: const ValueKey("hint"),
                      night: _isNightMode,
                      mutedText: mutedText,
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _ComposerActionBar(
              night: _isNightMode,
              aiPulse: _aiPulse,
              onAttach: _openAttachMenu,
              onAi: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AiChatScreen(emergencyType: widget.emergencyType),
                  ),
                );
              },
              isSending: _isSending,
              onSend: _isSending ? null : () => _sendEmergencySmart(direct: false),
              sendGradient: widget.colors,
            ),
          ),
          SizedBox(height: bottomPadding + 6),
        ],
      ),
    );
  }

  bool get _hasAnyAttachment {
    return _attachedImages.isNotEmpty ||
        _attachedVideos.isNotEmpty ||
        _hasAudio ||
        _attachedLocation != null ||
        (widget.initialLat != null && widget.initialLng != null);
  }

  void _clearAttachments() {
    setState(() {
      _attachedImages.clear();
      _attachedVideos.clear();
      _attachedLocation = null;
      _hasAudio = false;
      _audioFile = null;
      _isRecording = false;
    });
  }

  // =====================================================
  // Attach menu
  // =====================================================
  void _openAttachMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: _isNightMode ? const Color(0xFF0B1016) : Colors.white,
      builder: (context) {
        final textColor = _isNightMode ? Colors.white : Colors.black87;
        final iconColor = _isNightMode ? Colors.lightBlueAccent : Colors.blue.shade700;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAttachOption(
                  icon: Icons.camera_alt,
                  label: "Tomar foto",
                  textColor: textColor,
                  iconColor: iconColor,
                  action: _takePhoto,
                ),
                _buildAttachOption(
                  icon: Icons.photo,
                  label: "Elegir foto de galería",
                  textColor: textColor,
                  iconColor: iconColor,
                  action: _pickGalleryImage,
                ),
                _buildAttachOption(
                  icon: Icons.videocam,
                  label: "Grabar video",
                  textColor: textColor,
                  iconColor: iconColor,
                  action: _takeVideo,
                ),
                _buildAttachOption(
                  icon: Icons.video_collection,
                  label: "Elegir video de galería",
                  textColor: textColor,
                  iconColor: iconColor,
                  action: _pickGalleryVideo,
                ),
                _buildAttachOption(
                  icon: Icons.mic,
                  label: "Grabar audio",
                  textColor: textColor,
                  iconColor: iconColor,
                  action: _recordAudio,
                ),
                _buildAttachOption(
                  icon: Icons.location_on,
                  label: "Enviar ubicación",
                  textColor: textColor,
                  iconColor: iconColor,
                  action: _attachLocation,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachOption({
    required IconData icon,
    required String label,
    required Color textColor,
    required Color iconColor,
    required VoidCallback action,
  }) {
    return ListTile(
      leading: Icon(icon, size: 26, color: iconColor),
      title: Text(label, style: TextStyle(color: textColor)),
      onTap: () {
        Navigator.pop(context);
        action();
      },
    );
  }

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) setState(() => _attachedImages.add(photo));
  }

  Future<void> _pickGalleryImage() async {
    final XFile? img = await _picker.pickImage(source: ImageSource.gallery);
    if (img != null) setState(() => _attachedImages.add(img));
  }

  Future<void> _takeVideo() async {
    final XFile? vid = await _picker.pickVideo(source: ImageSource.camera);
    if (vid != null) setState(() => _attachedVideos.add(vid));
  }

  Future<void> _pickGalleryVideo() async {
    final XFile? vid = await _picker.pickVideo(source: ImageSource.gallery);
    if (vid != null) setState(() => _attachedVideos.add(vid));
  }

  Future<void> _recordAudio() async {
    try {
      final hasPerm = await _audioRecorder.hasPermission();
      if (!hasPerm) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Permiso de micrófono denegado")),
        );
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final path = "${tempDir.path}/safezone_audio_${DateTime.now().millisecondsSinceEpoch}.m4a";

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _hasAudio = false;
        _audioFile = null;
      });

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.mic, color: Colors.redAccent),
                SizedBox(width: 8),
                Text("Grabando audio"),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 8),
                Text(
                  "Habla cerca del micrófono.\nCuando termines, pulsa en Detener y adjuntar.",
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                _RecordingIndicator(),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final stopPath = await _audioRecorder.stop();
                  if (stopPath != null) {
                    setState(() {
                      _audioFile = File(stopPath);
                      _hasAudio = true;
                      _isRecording = false;
                    });
                  } else {
                    setState(() {
                      _audioFile = null;
                      _hasAudio = false;
                      _isRecording = false;
                    });
                  }
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text("Detener y adjuntar"),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al grabar audio: $e")),
      );
      setState(() => _isRecording = false);
    }
  }

  Future<void> _attachLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permiso de ubicación denegado')),
          );
          return;
        }
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() => _attachedLocation = pos);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error obteniendo ubicación: $e')),
      );
    }
  }
}

// =====================================================
// WIDGETS UI
// =====================================================

class _ComposerTextField extends StatelessWidget {
  final TextEditingController controller;
  final bool night;
  final Color primaryText;
  final Color mutedText;

  const _ComposerTextField({
    required this.controller,
    required this.night,
    required this.primaryText,
    required this.mutedText,
  });

  @override
  Widget build(BuildContext context) {
    final bg = night ? Colors.white.withOpacity(0.035) : Colors.black.withOpacity(0.03);
    final border = night ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: TextField(
        controller: controller,
        maxLines: 4,
        style: TextStyle(color: primaryText, fontSize: 15, height: 1.25),
        decoration: InputDecoration(
          hintText: "Describe lo que está pasando…",
          hintStyle: TextStyle(color: mutedText, fontSize: 13.5, height: 1.2),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        ),
      ),
    );
  }
}

class _AttachmentHintMini extends StatelessWidget {
  final bool night;
  final Color mutedText;

  const _AttachmentHintMini({
    super.key,
    required this.night,
    required this.mutedText,
  });

  @override
  Widget build(BuildContext context) {
    final bg = night ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.025);
    final border = night ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(Icons.attach_file, size: 16, color: mutedText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Adjunta evidencia si la tienes (foto, audio, ubicación).",
              style: TextStyle(
                color: mutedText,
                fontSize: 12.2,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentStrip extends StatelessWidget {
  final bool night;
  final Color secondaryText;
  final Color primaryText;

  final int imagesCount;
  final int videosCount;
  final bool hasAudio;
  final bool hasLocation;

  final VoidCallback onClear;

  const _AttachmentStrip({
    super.key,
    required this.night,
    required this.secondaryText,
    required this.primaryText,
    required this.imagesCount,
    required this.videosCount,
    required this.hasAudio,
    required this.hasLocation,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final bg = night ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.025);
    final border = night ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

    final chips = <Widget>[
      if (imagesCount > 0) _MiniChip(night: night, icon: Icons.photo, label: "$imagesCount"),
      if (videosCount > 0) _MiniChip(night: night, icon: Icons.videocam, label: "$videosCount"),
      if (hasAudio) _MiniChip(night: night, icon: Icons.mic, label: "1"),
      if (hasLocation) _MiniChip(night: night, icon: Icons.location_on, label: "OK"),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: secondaryText),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Text(
                  "Adjuntos listos",
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 12.6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: chips),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              foregroundColor: const Color(0xFF60A5FA),
            ),
            child: const Text("Limpiar", style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final bool night;
  final IconData icon;
  final String label;

  const _MiniChip({
    required this.night,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final bg = night ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.06);
    final border = night ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.07);
    final text = night ? Colors.white70 : Colors.black87;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: text),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ComposerActionBar extends StatelessWidget {
  final bool night;
  final Animation<double> aiPulse;
  final VoidCallback onAttach;
  final VoidCallback onAi;
  final bool isSending;
  final VoidCallback? onSend;
  final List<Color> sendGradient;

  const _ComposerActionBar({
    required this.night,
    required this.aiPulse,
    required this.onAttach,
    required this.onAi,
    required this.isSending,
    required this.onSend,
    required this.sendGradient,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconCircleButton(
          night: night,
          icon: Icons.add_rounded,
          tooltip: "Adjuntar",
          onTap: onAttach,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AnimatedBuilder(
            animation: aiPulse,
            builder: (_, __) =>
                Transform.scale(scale: aiPulse.value, child: _AiPillButton(onTap: onAi)),
          ),
        ),
        const SizedBox(width: 10),
        _SendCircleButton(isSending: isSending, onTap: onSend, gradient: sendGradient),
      ],
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  final bool night;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _IconCircleButton({
    required this.night,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = night ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05);
    final border = night ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.07);
    final fg = night ? Colors.white : Colors.black87;

    return Semantics(
      button: true,
      label: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: border),
          ),
          child: Icon(icon, color: fg, size: 26),
        ),
      ),
    );
  }
}

class _AiPillButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AiPillButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFF00E5FF)]),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C4DFF).withOpacity(0.30),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Asistente IA",
                style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w900),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              "Mejorar",
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendCircleButton extends StatelessWidget {
  final bool isSending;
  final VoidCallback? onTap;
  final List<Color> gradient;

  const _SendCircleButton({
    required this.isSending,
    required this.onTap,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: gradient),
          boxShadow: [
            BoxShadow(
              color: gradient.last.withOpacity(0.40),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: isSending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                )
              : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _RecordingIndicator extends StatefulWidget {
  const _RecordingIndicator();

  @override
  State<_RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<_RecordingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
          ..repeat(reverse: true);

    _scale = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.redAccent),
        child: const Icon(Icons.mic, color: Colors.white, size: 28),
      ),
    );
  }
}
