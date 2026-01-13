// lib/screens/create_community_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../routes/app_routes.dart';
import '../service/auth_service.dart';
import '../service/cloudinary_service.dart';
import '../config/api_config.dart';

// ✅ OFFLINE (cola simple local con SharedPreferences)
class OfflineCommunityRequest {
  final String clientGeneratedId;
  final String nombre;
  final String direccion;
  final int usuarioId;
  final double lat;
  final double lng;
  final double radio;
  final String localImagePath;
  final int createdAtMillis;

  OfflineCommunityRequest({
    required this.clientGeneratedId,
    required this.nombre,
    required this.direccion,
    required this.usuarioId,
    required this.lat,
    required this.lng,
    required this.radio,
    required this.localImagePath,
    required this.createdAtMillis,
  });

  Map<String, dynamic> toJson() => {
        "clientGeneratedId": clientGeneratedId,
        "nombre": nombre,
        "direccion": direccion,
        "usuarioId": usuarioId,
        "lat": lat,
        "lng": lng,
        "radio": radio,
        "localImagePath": localImagePath,
        "createdAtMillis": createdAtMillis,
      };

  static OfflineCommunityRequest fromJson(Map<String, dynamic> j) {
    return OfflineCommunityRequest(
      clientGeneratedId: (j["clientGeneratedId"] ?? "").toString(),
      nombre: (j["nombre"] ?? "").toString(),
      direccion: (j["direccion"] ?? "").toString(),
      usuarioId: (j["usuarioId"] as num).toInt(),
      lat: (j["lat"] as num).toDouble(),
      lng: (j["lng"] as num).toDouble(),
      radio: (j["radio"] as num).toDouble(),
      localImagePath: (j["localImagePath"] ?? "").toString(),
      createdAtMillis: (j["createdAtMillis"] as num).toInt(),
    );
  }
}

class OfflineCommunityQueue {
  static const _kKey = "offlineCommunityRequests";

  Future<List<OfflineCommunityRequest>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kKey) ?? const [];
    final out = <OfflineCommunityRequest>[];

    for (final s in raw) {
      try {
        final decoded = jsonDecode(s);
        if (decoded is Map<String, dynamic>) {
          out.add(OfflineCommunityRequest.fromJson(decoded));
        } else if (decoded is Map) {
          out.add(OfflineCommunityRequest.fromJson(decoded.cast<String, dynamic>()));
        }
      } catch (_) {}
    }
    return out;
  }

  Future<int> count() async => (await list()).length;

  Future<void> enqueue(OfflineCommunityRequest req) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kKey) ?? <String>[];
    raw.add(jsonEncode(req.toJson()));
    await prefs.setStringList(_kKey, raw);
  }

  Future<void> removeByClientId(String clientId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kKey) ?? <String>[];

    raw.removeWhere((s) {
      try {
        final j = jsonDecode(s);
        if (j is Map) {
          return (j["clientGeneratedId"] ?? "").toString() == clientId;
        }
        return false;
      } catch (_) {
        return false;
      }
    });

    await prefs.setStringList(_kKey, raw);
  }
}

class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final nombreController = TextEditingController();
  final direccionController = TextEditingController();
  final referenciaController = TextEditingController();

  bool _isLoading = false;

  File? _imageFile;

  double? _lat;
  double? _lng;

  double _radio = 5.0;

  late final AnimationController _cardController;
  late final Animation<double> _cardOpacity;
  late final Animation<Offset> _cardOffset;

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _isOnline = true;

  final OfflineCommunityQueue _offlineQueue = OfflineCommunityQueue();

  @override
  void initState() {
    super.initState();

    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _cardOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardController,
        curve: const Interval(0.15, 1.0, curve: Curves.easeOut),
      ),
    );

    _cardOffset = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _cardController,
        curve: const Interval(0.15, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _cardController.forward();
    _tryGetLocation();

    Future.microtask(() async {
      final r = await Connectivity().checkConnectivity();
      if (mounted) setState(() => _isOnline = _isConnected(r));

      _connSub = Connectivity().onConnectivityChanged.listen((res) async {
        final online = _isConnected(res);
        if (!mounted) return;
        setState(() => _isOnline = online);

        if (online) {
          await _syncOfflineQueueSilently();
        }
      });
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    nombreController.dispose();
    direccionController.dispose();
    referenciaController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  bool get _isNightMode => Theme.of(context).brightness == Brightness.dark;

  bool _isConnected(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    if (results.contains(ConnectivityResult.none)) return false;
    return true;
  }

  Future<bool> _hasInternetNow() async {
    final r = await Connectivity().checkConnectivity();
    return _isConnected(r);
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

  Future<void> _syncOfflineQueueSilently() async {
    try {
      if (!await _hasInternetNow()) return;

      await AuthService.restoreSession();

      final items = await _offlineQueue.list();
      if (items.isEmpty) return;

      for (final req in items) {
        final imgFile = File(req.localImagePath);
        if (!imgFile.existsSync()) {
          await _offlineQueue.removeByClientId(req.clientGeneratedId);
          continue;
        }

        final fotoUrl = await CloudinaryService.uploadImage(imgFile);
        if (fotoUrl == null) continue;

        final url = Uri.parse('${ApiConfig.baseUrl}/comunidades/solicitar');

        final body = jsonEncode({
          "nombre": req.nombre,
          "direccion": req.direccion,
          "usuarioId": req.usuarioId,
          "lat": req.lat,
          "lng": req.lng,
          "radio": req.radio,
          "fotoUrl": fotoUrl,
          "clientGeneratedId": req.clientGeneratedId,
          "canalEnvio": "OFFLINE_QUEUE",
        });

        final response = await http.post(
          url,
          headers: {
            ...AuthService.headers,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: body,
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          await _offlineQueue.removeByClientId(req.clientGeneratedId);
          try {
            await imgFile.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bool keyboardOpen = media.viewInsets.bottom > 0;
    final bool isNightMode = _isNightMode;

    final Color bgColor =
        isNightMode ? const Color(0xFF05070A) : const Color(0xFFF3F4F6);
    final Color cardColor =
        isNightMode ? const Color(0xFF0B1016) : Colors.white;
    final Color primaryText =
        isNightMode ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
    final Color secondaryText =
        isNightMode ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final Color mutedText =
        isNightMode ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);
    final Color headerIconColor = primaryText;
    final Color headerMuteIconColor =
        isNightMode ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);
    final Color inputFill =
        isNightMode ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    final Color inputBorder =
        isNightMode ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
    final Color cardShadowColor = isNightMode
        ? Colors.black.withOpacity(0.7)
        : Colors.black.withOpacity(0.06);

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            if (!keyboardOpen)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => AppRoutes.goBack(context),
                      icon: Icon(
                        Icons.arrow_back_ios_new,
                        color: headerIconColor,
                        size: 20,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          "Solicitar comunidad",
                          style: TextStyle(
                            color: primaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: isNightMode
                            ? Colors.white.withOpacity(0.07)
                            : Colors.black.withOpacity(0.05),
                        border: Border.all(
                          color: isNightMode
                              ? Colors.white.withOpacity(0.10)
                              : Colors.black.withOpacity(0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                            size: 14,
                            color: primaryText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isOnline ? "Online" : "Offline",
                            style: TextStyle(
                              color: primaryText,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: () async {
                        final c = await _offlineQueue.count();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Solicitudes pendientes en cola: $c")),
                        );
                      },
                      icon: Icon(
                        Icons.more_horiz,
                        color: headerMuteIconColor,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: media.viewInsets.bottom > 0 ? 20 : 0,
                ),
                child: Column(
                  mainAxisAlignment:
                      keyboardOpen ? MainAxisAlignment.start : MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),
                    if (!keyboardOpen)
                      Column(
                        children: [
                          Text(
                            "Crea tu comunidad con tus vecinos",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: primaryText,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Incluye foto y ubicación (centro) para registrar correctamente el radio de cobertura.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: secondaryText,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          FutureBuilder<int>(
                            future: _offlineQueue.count(),
                            builder: (_, snap) {
                              final pending = snap.data ?? 0;
                              if (pending <= 0) return const SizedBox.shrink();
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isNightMode
                                      ? Colors.orange.withOpacity(0.10)
                                      : Colors.orange.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isNightMode
                                        ? Colors.orange.withOpacity(0.25)
                                        : Colors.orange.withOpacity(0.30),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.schedule, color: Colors.orange.shade700),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        "Tienes $pending solicitud(es) pendientes. Se enviarán automáticamente al volver el internet.",
                                        style: TextStyle(
                                          color: primaryText,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 22),
                        ],
                      ),
                    AnimatedBuilder(
                      animation: _cardController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _cardOpacity.value,
                          child: SlideTransition(position: _cardOffset, child: child),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: cardShadowColor,
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Datos de la comunidad",
                                style: TextStyle(
                                  color: primaryText,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "La comunidad quedará SOLICITADA hasta que el super admin la apruebe.",
                                style: TextStyle(color: mutedText, fontSize: 12),
                              ),
                              const SizedBox(height: 18),

                              // FOTO
                              Text(
                                "Foto referencial *",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isNightMode
                                      ? const Color(0xFFE5E7EB)
                                      : const Color(0xFF374151),
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: inputBorder),
                                    color: inputFill,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        height: 52,
                                        width: 52,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          color: const Color(0xFFF3F4F6),
                                          image: _imageFile != null
                                              ? DecorationImage(
                                                  image: FileImage(_imageFile!),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: _imageFile == null
                                            ? const Icon(
                                                Icons.image_outlined,
                                                color: Color(0xFF9CA3AF),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _imageFile == null
                                              ? "Toca para subir una foto"
                                              : "Foto seleccionada",
                                          style: TextStyle(color: primaryText, fontSize: 13),
                                        ),
                                      ),
                                      const Icon(Icons.upload_rounded, color: Color(0xFF9CA3AF)),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // NOMBRE
                              Text(
                                "Nombre de la comunidad *",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isNightMode
                                      ? const Color(0xFFE5E7EB)
                                      : const Color(0xFF374151),
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: nombreController,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return "Ingresa el nombre de la comunidad";
                                  }
                                  return null;
                                },
                                style: TextStyle(color: primaryText),
                                decoration: _inputDecoration(
                                  hint: "Ej. Conjunto Los Rosales",
                                  icon: Icons.home_work_outlined,
                                  inputFill: inputFill,
                                  inputBorder: inputBorder,
                                ),
                              ),

                              const SizedBox(height: 16),

                              // DIRECCIÓN
                              Text(
                                "Dirección *",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isNightMode
                                      ? const Color(0xFFE5E7EB)
                                      : const Color(0xFF374151),
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: direccionController,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return "Ingresa la dirección de la comunidad";
                                  }
                                  return null;
                                },
                                style: TextStyle(color: primaryText),
                                decoration: _inputDecoration(
                                  hint: "Calle, número, barrio…",
                                  icon: Icons.place_outlined,
                                  inputFill: inputFill,
                                  inputBorder: inputBorder,
                                ),
                              ),

                              const SizedBox(height: 16),

                              // REFERENCIA
                              Text(
                                "Referencia / zona (opcional)",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isNightMode
                                      ? const Color(0xFFE5E7EB)
                                      : const Color(0xFF374151),
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: referenciaController,
                                style: TextStyle(color: primaryText),
                                maxLines: 2,
                                decoration: _inputDecoration(
                                  hint: "Ej. Cerca del parque central…",
                                  icon: Icons.map_outlined,
                                  inputFill: inputFill,
                                  inputBorder: inputBorder,
                                ),
                              ),

                              const SizedBox(height: 16),

                              // UBICACIÓN
                              Text(
                                "Ubicación (centro) *",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isNightMode
                                      ? const Color(0xFFE5E7EB)
                                      : const Color(0xFF374151),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: inputBorder),
                                  color: inputFill,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.my_location, color: Color(0xFF9CA3AF)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        (_lat != null && _lng != null)
                                            ? "Lat: ${_lat!.toStringAsFixed(6)}  Lng: ${_lng!.toStringAsFixed(6)}"
                                            : "Sin ubicación. Toca 'Obtener'",
                                        style: TextStyle(color: primaryText, fontSize: 13),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _tryGetLocation,
                                      child: const Text("Obtener"),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // RADIO
                              Text(
                                "Radio de cobertura (km) *",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isNightMode
                                      ? const Color(0xFFE5E7EB)
                                      : const Color(0xFF374151),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text("Sugerido: 5–10 km.",
                                  style: TextStyle(color: mutedText, fontSize: 12)),
                              Slider(
                                value: _radio,
                                min: 1,
                                max: 10,
                                divisions: 9,
                                label: "${_radio.toStringAsFixed(0)} km",
                                onChanged: (v) => setState(() => _radio = v),
                              ),

                              const SizedBox(height: 22),

                              _AnimatedPrimaryButton(
                                isLoading: _isLoading,
                                onTap: _isLoading ? null : _handleSendRequest,
                                label: _isOnline ? "Enviar solicitud" : "Guardar y enviar luego",
                              ),

                              const SizedBox(height: 14),

                              Text(
                                _isOnline
                                    ? "Un super admin revisará tu solicitud. Cuando sea aprobada, la comunidad pasará a ACTIVA y tú serás admin de esa comunidad."
                                    : "Estás sin internet. Guardaremos esta solicitud y se enviará automáticamente cuando vuelva la conexión.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: secondaryText,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galería'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1280,
                  maxHeight: 1280,
                  imageQuality: 80,
                );
                if (image != null) setState(() => _imageFile = File(image.path));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Cámara'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await picker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 1280,
                  maxHeight: 1280,
                  imageQuality: 80,
                );
                if (image != null) setState(() => _imageFile = File(image.path));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _tryGetLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Activa el GPS para obtener la ubicación.")),
        );
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Permiso de ubicación denegado permanentemente.")),
        );
        return;
      }

      if (perm == LocationPermission.denied) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo obtener la ubicación.")),
      );
    }
  }

  InputDecoration _inputDecoration({
    required String hint,
    IconData? icon,
    required Color inputFill,
    required Color inputBorder,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      filled: true,
      fillColor: inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      prefixIcon: icon != null ? Icon(icon, size: 20, color: const Color(0xFF9CA3AF)) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: inputBorder),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Color(0xFFE53935), width: 2),
      ),
    );
  }

  Future<void> _handleSendRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (_imageFile == null) {
      _showError("Por favor sube una foto referencial.");
      return;
    }
    if (_lat == null || _lng == null) {
      _showError("Por favor obtén la ubicación (GPS).");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService.restoreSession();

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');

      if (userId == null) {
        _showError("No se encontró el usuario actual. Vuelve a iniciar sesión.");
        return;
      }

      String direccionFinal = direccionController.text.trim();
      if (referenciaController.text.trim().isNotEmpty) {
        direccionFinal += " (${referenciaController.text.trim()})";
      }

      // ✅ OFFLINE: guardar y salir
      if (!await _hasInternetNow()) {
        final local = await _persistToOfflineMedia(_imageFile!.path, "community_");
        if (local == null) {
          _showError("No se pudo guardar la foto localmente.");
          return;
        }

        final clientId = "COMM_${DateTime.now().millisecondsSinceEpoch}_$userId";
        final req = OfflineCommunityRequest(
          clientGeneratedId: clientId,
          nombre: nombreController.text.trim(),
          direccion: direccionFinal,
          usuarioId: userId,
          lat: _lat!,
          lng: _lng!,
          radio: _radio,
          localImagePath: local,
          createdAtMillis: DateTime.now().millisecondsSinceEpoch,
        );

        await _offlineQueue.enqueue(req);

        if (!mounted) return;
        final c = await _offlineQueue.count();

        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.orange.shade700, size: 26),
                const SizedBox(width: 10),
                const Expanded(child: Text("Guardado sin internet")),
              ],
            ),
            content: Text(
              "Tu solicitud se guardó en el teléfono y se enviará automáticamente cuando vuelva el internet.\n\n"
              "Pendientes en cola: $c",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  AppRoutes.goBack(context);
                },
                child: const Text("Entendido"),
              ),
            ],
          ),
        );

        nombreController.clear();
        direccionController.clear();
        referenciaController.clear();
        setState(() => _imageFile = null);
        return;
      }

      // ✅ ONLINE: subir foto + post backend
      final fotoUrl = await CloudinaryService.uploadImage(_imageFile!);
      if (fotoUrl == null) {
        _showError("No se pudo subir la foto. Inténtalo de nuevo.");
        return;
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/comunidades/solicitar');
      final clientId = "COMM_${DateTime.now().millisecondsSinceEpoch}_$userId";

      final body = jsonEncode({
        "nombre": nombreController.text.trim(),
        "direccion": direccionFinal,
        "usuarioId": userId,
        "lat": _lat,
        "lng": _lng,
        "radio": _radio,
        "fotoUrl": fotoUrl,
        "clientGeneratedId": clientId,
        "canalEnvio": "ONLINE",
      });

      final response = await http.post(
        url,
        headers: {
          ...AuthService.headers,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: body,
      );

      if (!mounted) return;

      if (response.statusCode == 201 || response.statusCode == 200) {
        await _showRequestSentDialog();
        // limpiar form
        nombreController.clear();
        direccionController.clear();
        referenciaController.clear();
        setState(() => _imageFile = null);
      } else {
        final msg = _tryExtractMessage(response.body) ??
            "No se pudo enviar (código ${response.statusCode}).";
        _showError(msg);
      }
    } on SocketException catch (_) {
      if (mounted) {
        _showError("Se perdió la conexión. Si estás sin internet, se guardará para enviar luego.");
      }
    } catch (_) {
      if (!mounted) return;
      _showError("Error de conexión. Verifica internet y backend.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _tryExtractMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _showRequestSentDialog() async {
    final bool night = _isNightMode;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: night ? const Color(0xFF0B1016) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Color(0xFFE53935)),
              SizedBox(width: 10),
              Expanded(child: Text("Solicitud enviada")),
            ],
          ),
          content: const Text(
            "Tu comunidad quedó SOLICITADA.\n\n"
            "El super admin la revisará. Cuando sea aprobada, la comunidad pasará a ACTIVA y tú serás administrador de esa comunidad.\n\n"
            "Te llegará una notificación cuando esté aprobada.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                AppRoutes.goBack(context);
              },
              child: const Text(
                "Aceptar",
                style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class _AnimatedPrimaryButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback? onTap;
  final String label;

  const _AnimatedPrimaryButton({
    required this.isLoading,
    required this.onTap,
    required this.label,
  });

  @override
  State<_AnimatedPrimaryButton> createState() => _AnimatedPrimaryButtonState();
}

class _AnimatedPrimaryButtonState extends State<_AnimatedPrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 0.07,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null) _pressController.forward();
  }

  void _onTapUp(TapUpDetails _) => _pressController.reverse();
  void _onTapCancel() => _pressController.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? _onTapDown : null,
      onTapUp: widget.onTap != null ? _onTapUp : null,
      onTapCancel: widget.onTap != null ? _onTapCancel : null,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pressController,
        builder: (context, child) => Transform.scale(scale: _scale.value, child: child),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFFFF5A5A), Color(0xFFE53935)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE53935).withOpacity(0.5),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
