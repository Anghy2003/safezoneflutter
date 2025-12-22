import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../routes/app_routes.dart';
import '../service/cloudinary_service.dart';

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

  // ✅ Foto referencial
  File? _imageFile;

  // ✅ Ubicación
  double? _lat;
  double? _lng;

  // ✅ Radio alto (km)
  double _radio = 5.0;

  static const String _baseUrl = 'http://192.168.3.25:8080';

  late final AnimationController _cardController;
  late final Animation<double> _cardOpacity;
  late final Animation<Offset> _cardOffset;

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

    // ✅ Opcional: intenta obtener ubicación al abrir
    _tryGetLocation();
  }

  @override
  void dispose() {
    nombreController.dispose();
    direccionController.dispose();
    referenciaController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bool keyboardOpen = media.viewInsets.bottom > 0;

    // ⏰ MODO NOCHE: 19:00–06:00
    final hour = DateTime.now().hour;
    final bool isNightMode = hour >= 19 || hour < 6;

    // 🎨 PALETA DINÁMICA
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
    final Color headerIconColor =
        isNightMode ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
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
            // 🔝 HEADER
            if (!keyboardOpen)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                          "Crear comunidad",
                          style: TextStyle(
                            color: primaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
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
                  mainAxisAlignment: keyboardOpen
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),

                    if (!keyboardOpen)
                      Column(
                        children: [
                          Text(
                            "Crea la comunidad con tus vecinos",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: primaryText,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Ahora también pedimos foto y ubicación (centro) para registrar correctamente el radio de cobertura.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: secondaryText,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 22),
                        ],
                      ),

                    // 🧊 CARD FORM animada
                    AnimatedBuilder(
                      animation: _cardController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _cardOpacity.value,
                          child: SlideTransition(
                            position: _cardOffset,
                            child: child,
                          ),
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
                                "Incluye foto + ubicación para validar la comunidad.",
                                style: TextStyle(
                                  color: mutedText,
                                  fontSize: 12,
                                ),
                              ),

                              const SizedBox(height: 18),

                              // ✅ FOTO REFERENCIAL (como RegisterScreen)
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
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          color: const Color(0xFFF3F4F6),
                                          image: _imageFile != null
                                              ? DecorationImage(
                                                  image:
                                                      FileImage(_imageFile!),
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
                                          style: TextStyle(
                                            color: primaryText,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      const Icon(Icons.upload_rounded,
                                          color: Color(0xFF9CA3AF)),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Nombre comunidad
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
                                  if (value == null ||
                                      value.trim().isEmpty) {
                                    return "Ingresa el nombre de la comunidad";
                                  }
                                  return null;
                                },
                                style: TextStyle(color: primaryText),
                                decoration: _inputDecoration(
                                  hint: "Ej. Conjunto Los Rosales",
                                  icon: Icons.home_work_outlined,
                                  isNightMode: isNightMode,
                                  inputFill: inputFill,
                                  inputBorder: inputBorder,
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Dirección
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
                                  if (value == null ||
                                      value.trim().isEmpty) {
                                    return "Ingresa la dirección de la comunidad";
                                  }
                                  return null;
                                },
                                style: TextStyle(color: primaryText),
                                decoration: _inputDecoration(
                                  hint: "Calle, número, barrio…",
                                  icon: Icons.place_outlined,
                                  isNightMode: isNightMode,
                                  inputFill: inputFill,
                                  inputBorder: inputBorder,
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Referencia
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
                                  hint:
                                      "Ej. Cerca del parque central, junto a la iglesia…",
                                  icon: Icons.map_outlined,
                                  isNightMode: isNightMode,
                                  inputFill: inputFill,
                                  inputBorder: inputBorder,
                                ),
                              ),

                              const SizedBox(height: 16),

                              // ✅ UBICACIÓN
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
                                    const Icon(
                                      Icons.my_location,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        (_lat != null && _lng != null)
                                            ? "Lat: ${_lat!.toStringAsFixed(6)}  Lng: ${_lng!.toStringAsFixed(6)}"
                                            : "Sin ubicación. Toca 'Obtener'",
                                        style: TextStyle(
                                          color: primaryText,
                                          fontSize: 13,
                                        ),
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

                              // ✅ RADIO ALTO
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
                              Text(
                                "Sugerido para pruebas: 5–10 km.",
                                style: TextStyle(
                                  color: mutedText,
                                  fontSize: 12,
                                ),
                              ),
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
                                label: "Enviar solicitud",
                              ),

                              const SizedBox(height: 14),

                              Text(
                                "Un administrador revisará los datos. Cuando la comunidad sea aprobada, recibirás tu código de acceso para compartirlo con tus vecinos.",
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

  // ✅ Igual que tu RegisterScreen: Galería / Cámara
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
                if (image != null) {
                  setState(() => _imageFile = File(image.path));
                }
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
                if (image != null) {
                  setState(() => _imageFile = File(image.path));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Ubicación con Geolocator
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

  // 🔹 Input decoration base (igual que Login)
  InputDecoration _inputDecoration({
    required String hint,
    IconData? icon,
    required bool isNightMode,
    required Color inputFill,
    required Color inputBorder,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      filled: true,
      fillColor: inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      prefixIcon: icon != null
          ? Icon(icon, size: 20, color: const Color(0xFF9CA3AF))
          : null,
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

    // ✅ Validar foto y ubicación
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
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');

      if (userId == null) {
        _showError("No se encontró el usuario actual. Vuelve a iniciar sesión.");
        return;
      }

      // 1) Subir foto a Cloudinary (igual que registro)
      final fotoUrl = await CloudinaryService.uploadImage(_imageFile!);
      if (fotoUrl == null) {
        _showError("No se pudo subir la foto. Inténtalo de nuevo.");
        return;
      }

      final url = Uri.parse('$_baseUrl/api/comunidades/solicitar');

      String direccionFinal = direccionController.text.trim();
      if (referenciaController.text.trim().isNotEmpty) {
        direccionFinal += " (${referenciaController.text.trim()})";
      }

      final body = jsonEncode({
        "nombre": nombreController.text.trim(),
        "direccion": direccionFinal,
        "usuarioId": userId,
        "lat": _lat,
        "lng": _lng,
        "radio": _radio,    // ✅ radio alto
        "fotoUrl": fotoUrl, // ✅ foto
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (!mounted) return;

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Solicitud enviada. El administrador revisará tu comunidad."),
          ),
        );
        AppRoutes.navigateTo(context, AppRoutes.verifySuccess);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("No se pudo enviar (código ${response.statusCode})."),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      _showError("Error de conexión. Verifica internet y backend.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

/// 🔴 Botón rojo animado (igual al tuyo)
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
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
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
