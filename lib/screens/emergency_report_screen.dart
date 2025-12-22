// lib/screens/emergency_report_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../routes/app_routes.dart';
import '../service/auth_service.dart';
import '../service/cloudinary_service.dart';
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
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  static const String _baseUrl = "http://192.168.3.25:8080/api";

  late final AnimationController _aiIconController;

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

  bool get _isNightMode {
    final hour = DateTime.now().hour;
    return hour >= 19 || hour < 6;
  }

  Map<String, String> get _jsonHeaders {
    return {
      ...AuthService.headers,
      'Content-Type': 'application/json',
    };
  }

  @override
  void initState() {
    super.initState();

    AuthService.restoreSession();

    _aiIconController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
      lowerBound: 0.9,
      upperBound: 1.1,
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
    _aiIconController.dispose();
    _messageController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  // =====================================================
  // HOLD BUTTON
  // =====================================================
  void _startHoldToSend() {
    if (_isSending) return;

    _holdTimer?.cancel();
    setState(() {
      _isHolding = true;
      _holdProgress = 0.0;
    });

    final int tickMs = 40;
    int elapsed = 0;

    _holdTimer = Timer.periodic(Duration(milliseconds: tickMs), (t) async {
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

        await _sendEmergency();
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
    final Color cardShadow = _isNightMode
        ? Colors.black.withOpacity(0.7)
        : Colors.black.withOpacity(0.07);

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
                  colors: [
                    widget.colors.first.withOpacity(0.25),
                    Colors.transparent,
                  ],
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
                  colors: [
                    widget.colors.last.withOpacity(0.22),
                    Colors.transparent,
                  ],
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
                    widget.colors.first.withOpacity(0.9),
                    widget.colors.last.withOpacity(0.7),
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
                _buildHeader(primaryText),
                const SizedBox(height: 18),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _buildBanner(
                            cardColor, cardShadow, primaryText, secondaryText),
                        const SizedBox(height: 18),
                        _buildHoldBubbleCard(
                          cardColor: cardColor,
                          cardShadow: cardShadow,
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                        ),
                        const SizedBox(height: 18),
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

  Widget _buildHeader(Color primaryText) {
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
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                size: 18,
                color: Colors.white,
              ),
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
                  fontWeight: FontWeight.w700,
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
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner(Color cardColor, Color cardShadow, Color primaryText,
      Color secondaryText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cardShadow,
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: _isNightMode
              ? Colors.white.withOpacity(0.06)
              : Colors.white.withOpacity(0.85),
          width: 1.6,
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
                    fontWeight: FontWeight.bold,
                    color: primaryText,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Describe lo que ocurre para alertar a tu comunidad y a los servicios de ayuda.",
                  style: TextStyle(fontSize: 13, color: secondaryText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Image.asset(
            'assets/images/emergency_illustration.png',
            width: 105,
            height: 105,
          ),
        ],
      ),
    );
  }

  Widget _buildHoldBubbleCard({
    required Color cardColor,
    required Color cardShadow,
    required Color primaryText,
    required Color secondaryText,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: cardShadow, blurRadius: 16, offset: const Offset(0, 8)),
        ],
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
                  width: 140,
                  height: 140,
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
                  child: Center(
                    child: Icon(widget.icon, color: Colors.white, size: 44),
                  ),
                ),
                if (_isHolding || _holdProgress > 0)
                  SizedBox(
                    width: 156,
                    height: 156,
                    child: CircularProgressIndicator(
                      value: _holdProgress,
                      strokeWidth: 6,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withOpacity(0.95)),
                      backgroundColor: Colors.white.withOpacity(0.12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _isHolding
                ? "Enviando... ${(3 * _holdProgress).clamp(0, 3).toStringAsFixed(1)}s"
                : "Mantén presionado 3s",
            style: TextStyle(
              color: secondaryText,
              fontSize: 12.5,
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
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: cardShadow, blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _messageController,
            maxLines: 4,
            style: TextStyle(color: primaryText, fontSize: 14),
            decoration: InputDecoration(
              hintText: "Describe lo que está pasando...",
              hintStyle: TextStyle(color: mutedText, fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          if (_hasAnyAttachment)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: _buildAttachmentSummary(
                primaryText: primaryText,
                secondaryText: secondaryText,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _openAttachMenu,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 26),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AiChatScreen(emergencyType: widget.emergencyType),
                      ),
                    );
                  },
                  tooltip: 'Asistente IA',
                  icon: AnimatedBuilder(
                    animation: _aiIconController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _aiIconController.value,
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF7C4DFF), Color(0xFF00E5FF)],
                            ),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: const Icon(Icons.smart_toy,
                              size: 22, color: Colors.white),
                        ),
                      );
                    },
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _isSending ? null : _sendEmergency,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: widget.colors),
                      boxShadow: [
                        BoxShadow(
                          color: widget.colors.last.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: _isSending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 40 + bottomPadding),
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

  Widget _buildAttachmentSummary({
    required Color primaryText,
    required Color secondaryText,
  }) {
    final pieces = <String>[];
    if (_attachedImages.isNotEmpty) pieces.add("${_attachedImages.length} foto(s)");
    if (_attachedVideos.isNotEmpty) pieces.add("${_attachedVideos.length} video(s)");
    if (_hasAudio) pieces.add("audio");
    if (_attachedLocation != null) pieces.add("ubicación");

    final text =
        pieces.isEmpty ? "Adjuntos listos" : "Adjuntos: ${pieces.join(" · ")}";

    return Row(
      children: [
        Icon(Icons.attach_file, size: 18, color: secondaryText),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: secondaryText,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(onPressed: _clearAttachments, child: const Text("Limpiar")),
      ],
    );
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
        final iconColor =
            _isNightMode ? Colors.lightBlueAccent : Colors.blue.shade700;

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
      final path =
          "${tempDir.path}/safezone_audio_${DateTime.now().millisecondsSinceEpoch}.m4a";

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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
      debugPrint("Error grabando audio: $e");
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
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied ||
            perm == LocationPermission.deniedForever) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permiso de ubicación denegado')),
          );
          return;
        }
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() => _attachedLocation = pos);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error obteniendo ubicación: $e')),
      );
    }
  }

  Future<Position?> _resolveLocationIfNeeded() async {
    if (_attachedLocation != null) return _attachedLocation;

    if (widget.initialLat != null && widget.initialLng != null) {
      return Position(
        latitude: widget.initialLat!,
        longitude: widget.initialLng!,
        timestamp: DateTime.now(),
        accuracy: 50,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    }

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (_) {
      return null;
    }
  }

  // =====================================================
  // Determinar canal del chat
  // =====================================================
  String _resolveChatCanal() {
    final src = (widget.source ?? "").toUpperCase().trim();
    if (src == "VECINOS") return "VECINOS";
    if (src == "COMUNIDAD") return "COMUNIDAD";
    return "COMUNIDAD";
  }

  // =====================================================
  // Publicar mensaje en chat por REST
  // =====================================================
  Future<void> _postIncidentToChat({
    required String descripcion,
    required String incidenteId,
    required String canal,
    required String? imagenUrl,
    required String? videoUrl,
    required String? audioUrl,
  }) async {
    if (_resolvedUsuarioId == null || _resolvedComunidadId == null) return;

    final payload = <String, dynamic>{
      "usuarioId": _resolvedUsuarioId,
      "comunidadId": _resolvedComunidadId,
      "canal": canal,
      "tipo": "incidente",
      "mensaje": descripcion,
      "imagenUrl": imagenUrl,
      "videoUrl": videoUrl,
      "audioUrl": audioUrl,
      "incidenteId": incidenteId,
      "replyToId": null,
    }..removeWhere((k, v) => v == null);

    final resp = await http.post(
      Uri.parse("$_baseUrl/mensajes-comunidad/enviar"),
      headers: _jsonHeaders,
      body: jsonEncode(payload),
    );

    if (resp.statusCode != 201 && resp.statusCode != 200) {
      throw Exception("Error chat ${resp.statusCode}: ${resp.body}");
    }
  }

  // =====================================================
  // IA — GENERAR MINIATURA DEL VIDEO
  // =====================================================
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
    } catch (e) {
      debugPrint("Error generando thumbnail IA: $e");
      return null;
    }
  }

  // =====================================================
  // LLAMAR IA — ANALIZAR INCIDENTE
  // =====================================================
  Future<Map<String, dynamic>> _analyzeWithIA({
    required String descripcion,
    String? imagenUrl,
    String? videoThumbUrl,
    String? audioTranscripcion,
  }) async {
    final aiPayload = {
      "text": descripcion,
      "imageUrls": [
        if (imagenUrl != null) imagenUrl,
        if (videoThumbUrl != null) videoThumbUrl,
      ],
      "audioTranscript": audioTranscripcion,
      "userContext": "usuario $_resolvedUsuarioId",
    };

    final resp = await http.post(
      Uri.parse("$_baseUrl/ai/analyze-incident"),
      headers: _jsonHeaders,
      body: jsonEncode(aiPayload),
    );

    if (resp.statusCode != 200) {
      throw Exception("Error IA ${resp.statusCode}: ${resp.body}");
    }

    final Map<String, dynamic> j = jsonDecode(resp.body);

    // --- Compatibilidad por si backend devuelve possible_fake ---
    if (!j.containsKey("possibleFake") && j.containsKey("possible_fake")) {
      j["possibleFake"] = j["possible_fake"];
    }
    if (!j.containsKey("risk_flags") && j.containsKey("riskFlags")) {
      j["risk_flags"] = j["riskFlags"];
    }

    return j;
  }

  // =====================================================
  // Helpers: reglas de bloqueo por IA
  // =====================================================
  bool _shouldBlockPublish({required bool possibleFake, required String priority}) {
    final pr = priority.toUpperCase().trim();
    return possibleFake == true || pr == "BAJA";
  }

  Future<void> _showBlockedDialog({
    required String category,
    required String priority,
    required bool possibleFake,
    required List reasons,
  }) async {
    if (!mounted) return;

    final reasonsText = reasons.isEmpty
        ? ""
        : "\n\nMotivos:\n- ${reasons.take(3).join("\n- ")}";

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
          "Tipo: $category\n"
          "Prioridad: $priority\n"
          "Posible falso: ${possibleFake ? "Sí" : "No"}"
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
  // ENVIAR EMERGENCIA (INCIDENTE + IA + CHAT)
  // =====================================================
  Future<void> _sendEmergency() async {
    if (_isSending) return;

    final msg = _messageController.text.trim();

    // Nota: mantenemos tu validación original
    if (msg.isEmpty &&
        _attachedLocation == null &&
        _attachedImages.isEmpty &&
        _attachedVideos.isEmpty &&
        !_hasAudio &&
        (widget.initialLat == null || widget.initialLng == null)) {
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

    // Si estaba grabando, detenemos antes de enviar
    if (_isRecording) {
      final stopPath = await _audioRecorder.stop();
      if (stopPath != null) {
        _audioFile = File(stopPath);
        _hasAudio = true;
      }
      _isRecording = false;
    }

    setState(() => _isSending = true);

    try {
      // Importante: evitar texto genérico que dispara "possible_fake"
      final descripcion = msg.isNotEmpty ? msg : "Reporte: ${widget.emergencyType}.";

      final pos = await _resolveLocationIfNeeded();
      final latToSend = pos?.latitude;
      final lngToSend = pos?.longitude;

      String? imagenUrl;
      String? videoUrl;
      String? videoThumbUrl;
      String? audioUrl;

      // =========================
      // SUBIR EVIDENCIA
      // =========================
      if (_attachedImages.isNotEmpty) {
        imagenUrl =
            await CloudinaryService.uploadImage(File(_attachedImages.first.path));
      }

      if (_attachedVideos.isNotEmpty) {
        final file = File(_attachedVideos.first.path);
        videoUrl = await CloudinaryService.uploadVideo(file);
        videoThumbUrl = await _generateVideoThumbnailUrl(file.path);
      }

      if (_hasAudio && _audioFile != null) {
        audioUrl = await CloudinaryService.uploadAudio(_audioFile!);
      }

      // =========================
      // ANALIZAR CON IA
      // =========================
      final aiJson = await _analyzeWithIA(
        descripcion: descripcion,
        imagenUrl: imagenUrl,
        videoThumbUrl: videoThumbUrl,
        audioTranscripcion: null,
      );

      final String aiCategory = (aiJson["category"] ?? widget.emergencyType).toString();
      final String aiPriority = (aiJson["priority"] ?? "MEDIA").toString();
      final bool aiFake = (aiJson["possibleFake"] ?? false) == true;
      final double? aiConf =
          aiJson["confidence"] is num ? (aiJson["confidence"] as num).toDouble() : null;
      final List aiReasons = (aiJson["reasons"] is List) ? aiJson["reasons"] : [];
      final List aiRisks = (aiJson["risk_flags"] is List) ? aiJson["risk_flags"] : [];
      final String? aiAction =
          aiJson["recommended_action"] != null ? aiJson["recommended_action"].toString() : null;

      // =====================================================
      // ✅ BLOQUEO: si es BAJA o posible falso => NO guardar, NO chat, NO mapa
      // =====================================================
      if (_shouldBlockPublish(possibleFake: aiFake, priority: aiPriority)) {
        await _showBlockedDialog(
          category: aiCategory,
          priority: aiPriority,
          possibleFake: aiFake,
          reasons: aiReasons,
        );
        return;
      }

      // =====================================================
      // CREAR INCIDENTE EN BACKEND (solo si pasa el filtro)
      // =====================================================
      final body = <String, dynamic>{
        "tipo": aiCategory,
        "descripcion": descripcion,
        "nivelPrioridad": aiPriority,
        "imagenUrl": imagenUrl,
        "videoUrl": videoUrl,
        "audioUrl": audioUrl,
        "usuarioId": _resolvedUsuarioId,
        "comunidadId": _resolvedComunidadId,
        "lat": latToSend,
        "lng": lngToSend,

        // IA
        "aiCategoria": aiCategory,
        "aiPrioridad": aiPriority,
        "aiConfianza": aiConf,
        "aiPosibleFalso": aiFake,
        "aiMotivos": jsonEncode(aiReasons),
        "aiRiesgos": jsonEncode(aiRisks),
        "aiAccionRecomendada": aiAction,
      }..removeWhere((k, v) => v == null);

      final resp = await http.post(
        Uri.parse("$_baseUrl/incidentes"),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      );

      if (resp.statusCode != 201 && resp.statusCode != 200) {
        throw Exception("Error creando incidente: ${resp.body}");
      }

      final decoded = jsonDecode(resp.body);
      final incidenteId = (decoded["id"] ?? "").toString();

      // =====================================================
      // PUBLICAR EN CHAT
      // =====================================================
      final canal = _resolveChatCanal();
      await _postIncidentToChat(
        descripcion: descripcion,
        incidenteId: incidenteId,
        canal: canal,
        imagenUrl: imagenUrl,
        videoUrl: videoUrl,
        audioUrl: audioUrl,
      );

      if (!mounted) return;

      // =====================================================
      // DIÁLOGO DE CONFIRMACIÓN (solo si se publicó)
      // =====================================================
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
            "Clasificación IA:\n"
            "Tipo: $aiCategory\n"
            "Prioridad: $aiPriority\n"
            "Posible Falso: ${aiFake ? "Sí" : "No"}",
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

  Future<void> _createNotificationsForIncident({
    required String descripcion,
    required dynamic incidenteId,
    required double? lat,
    required double? lng,
  }) async {
    // Tu backend ya notifica, así que dejamos vacío.
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
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

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
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.redAccent,
        ),
        child: const Icon(Icons.mic, color: Colors.white, size: 28),
      ),
    );
  }
}
