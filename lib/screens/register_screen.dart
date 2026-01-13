// lib/screens/register_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flag_secure/flag_secure.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';

import '../routes/app_routes.dart';
import '../service/auth_service.dart';
import '../service/cloudinary_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final nameController = TextEditingController();
  final apellidoController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  bool obscurePassword = true;
  File? _imageFile;
  bool _isLoading = false;

  // ✅ Prefill desde Google
  bool _fromGoogle = false;
  String? _googlePhotoUrl;
  bool _isGoogleLoading = false;

  // Usa el mismo serverClientId que en LoginScreen
  static const String _serverClientId =
      "148831363300-1gmm6f3rls7pflfmk6dp6jm5cd601tqb.apps.googleusercontent.com";

  late final AnimationController _controller;
  late final Animation<double> _avatarScale;
  late final Animation<double> _cardOpacity;
  late final Animation<Offset> _cardOffset;

  // ==========================
  // 🔒 Android: bloquear screenshots / grabación
  // ==========================
  Future<void> _secureScreenOn() async {
    if (!Platform.isAndroid) return;
    try {
      await FlagSecure.set();
    } catch (_) {}
  }

  Future<void> _secureScreenOff() async {
    if (!Platform.isAndroid) return;
    try {
      await FlagSecure.unset();
    } catch (_) {}
  }

  // ==========================
  // ✅ Internet check (rápido)
  // ==========================
  Future<bool> _hasInternetNow() async {
    final r = await Connectivity().checkConnectivity();
    return r != ConnectivityResult.none;
  }

  // ==========================
  // ✅ Borrador local (Hive)
  // ==========================
  final RegisterDraftCache _draft = RegisterDraftCache.instance;

  @override
  void initState() {
    super.initState();

    // ✅ Bloquea capturas SOLO en esta pantalla (Android)
    _secureScreenOn();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _avatarScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _cardOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 1.0, curve: Curves.easeOut),
      ),
    );

    _cardOffset =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();

    // ✅ Leer args + cargar borrador
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 1) Args (cuando se viene desde Login con Google)
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        final email = (args['email'] ?? '').toString().trim();
        final name = (args['name'] ?? '').toString().trim();
        final picture = (args['picture'] ?? '').toString().trim();

        if (email.isNotEmpty || name.isNotEmpty || picture.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _fromGoogle = true;
            _googlePhotoUrl = picture.isNotEmpty ? picture : null;
          });

          if (email.isNotEmpty && emailController.text.trim().isEmpty) {
            emailController.text = email;
          }

          if (name.isNotEmpty &&
              nameController.text.trim().isEmpty &&
              apellidoController.text.trim().isEmpty) {
            final parts =
                name.split(' ').where((e) => e.trim().isNotEmpty).toList();
            if (parts.isNotEmpty) {
              nameController.text = parts.first;
              if (parts.length > 1) {
                apellidoController.text = parts.sublist(1).join(' ');
              }
            }
          }
        }
      }

      // 2) Borrador (solo rellena campos vacíos; nunca contraseña)
      try {
        await _draft.init();
        final d = _draft.read();
        if (d != null) {
          if (nameController.text.trim().isEmpty && (d.name?.isNotEmpty ?? false)) {
            nameController.text = d.name!;
          }
          if (apellidoController.text.trim().isEmpty && (d.apellido?.isNotEmpty ?? false)) {
            apellidoController.text = d.apellido!;
          }
          if (emailController.text.trim().isEmpty && (d.email?.isNotEmpty ?? false)) {
            // si vino de Google, el email queda readOnly, pero igual puede estar vacío
            emailController.text = d.email!;
          }
          if (phoneController.text.trim().isEmpty && (d.telefono?.isNotEmpty ?? false)) {
            phoneController.text = d.telefono!;
          }

          // Foto: si no hay una ya seleccionada por UI
          if (_imageFile == null && (_googlePhotoUrl == null || _googlePhotoUrl!.trim().isEmpty)) {
            if (d.googlePhotoUrl != null && d.googlePhotoUrl!.trim().isNotEmpty) {
              if (!mounted) return;
              setState(() => _googlePhotoUrl = d.googlePhotoUrl);
            } else if (d.localImagePath != null && d.localImagePath!.trim().isNotEmpty) {
              final f = File(d.localImagePath!);
              if (await f.exists()) {
                if (!mounted) return;
                setState(() => _imageFile = f);
              }
            }
          }
        }
      } catch (_) {
        // si Hive no está listo por alguna razón, no bloqueamos la pantalla
      }
    });
  }

  @override
  void dispose() {
    // ✅ Libera el bloqueo al salir (Android)
    _secureScreenOff();

    nameController.dispose();
    apellidoController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bool night = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor =
        night ? const Color(0xFF05070A) : const Color(0xFFFFF5F5);
    final Color cardColor = night ? const Color(0xFF0B1016) : Colors.white;
    final Color primaryText =
        night ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
    final Color secondaryText =
        night ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    final Color inputFill =
        night ? const Color(0xFF111827) : const Color(0xFFFFFBFB);
    final Color inputBorder =
        night ? const Color(0xFF1F2937) : const Color(0xFFF3D6D6);

    final Color headerIconColor = primaryText;
    final Color headerMuteIconColor =
        night ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);

    final Color cardShadowColor =
        night ? Colors.black.withOpacity(0.70) : Colors.black.withOpacity(0.08);

    final Gradient bgGradient = night
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF05070A), Color(0xFF000000)],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF5F5),
              Color(0xFFFFEBEE),
              Color(0xFFFFFFFF),
            ],
          );

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(decoration: BoxDecoration(gradient: bgGradient)),
          ),
          Positioned(
            top: -90,
            right: -70,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFE53935).withOpacity(night ? 0.35 : 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -110,
            left: -70,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFF5A5A).withOpacity(night ? 0.18 : 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: media.viewInsets.bottom + 20,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight -
                          media.padding.top -
                          media.padding.bottom,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
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
                                    "Crear cuenta",
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
                        const SizedBox(height: 12),

                        // Avatar
                        AnimatedBuilder(
                          animation: _avatarScale,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _avatarScale.value,
                              child: child,
                            );
                          },
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Column(
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFFFF6B6B),
                                            Color(0xFFE53935),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFE53935)
                                                .withOpacity(
                                                    night ? 0.50 : 0.30),
                                            blurRadius: 18,
                                            spreadRadius: 3,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: CircleAvatar(
                                        radius: 46,
                                        backgroundColor: night
                                            ? const Color(0xFF0B1016)
                                            : Colors.white,
                                        backgroundImage: _imageFile != null
                                            ? FileImage(_imageFile!)
                                            : (_googlePhotoUrl != null
                                                ? NetworkImage(_googlePhotoUrl!)
                                                    as ImageProvider
                                                : null),
                                        child: (_imageFile == null &&
                                                _googlePhotoUrl == null)
                                            ? const Icon(
                                                Icons.person_rounded,
                                                size: 50,
                                                color: Color(0xFFE53935),
                                              )
                                            : null,
                                      ),
                                    ),
                                    Positioned(
                                      bottom: -2,
                                      right: -2,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFFE53935),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.18),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Elige tu avatar",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: primaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Card principal
                        AnimatedBuilder(
                          animation: _controller,
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
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
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
                              border: Border.all(
                                color: night
                                    ? const Color(0xFF1F2937)
                                    : const Color(0xFFF5DADA),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Crear cuenta",
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    color: primaryText,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _fromGoogle
                                      ? "Completa tu registro legal (Google verificado)."
                                      : "Registro legal en SafeZone (Ecuador).",
                                  style: TextStyle(
                                    color: secondaryText,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // ===== Botón "Completar con Google" =====
                                if (!_fromGoogle) ...[
                                  GestureDetector(
                                    onTap: _isGoogleLoading
                                        ? null
                                        : _handleGooglePrefill,
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 150),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 11),
                                      decoration: BoxDecoration(
                                        color: night
                                            ? const Color(0xFF111827)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border:
                                            Border.all(color: inputBorder),
                                        boxShadow: [
                                          if (!night)
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.03),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          if (_isGoogleLoading)
                                            const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2),
                                            )
                                          else ...[
                                            Image.asset(
                                              "assets/images/google.png",
                                              width: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              "Completar con Google",
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: primaryText,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // ===== Campos =====
                                _buildTextField(
                                  label: "Nombre *",
                                  controller: nameController,
                                  hint: "Ingresa tu nombre",
                                  night: night,
                                  inputFill: inputFill,
                                  inputBorder: inputBorder,
                                  labelColor: primaryText,
                                  textColor: primaryText,
                                ),
                                const SizedBox(height: 12),

                                _buildTextField(
                                  label: "Apellido *",
                                  controller: apellidoController,
                                  hint: "Ingresa tu apellido",
                                  night: night,
                                  inputFill: inputFill,
                                  inputBorder: inputBorder,
                                  labelColor: primaryText,
                                  textColor: primaryText,
                                ),
                                const SizedBox(height: 12),

                                _buildTextField(
                                  label: "Correo Electrónico *",
                                  controller: emailController,
                                  hint: "example@gmail.com",
                                  keyboardType: TextInputType.emailAddress,
                                  night: night,
                                  inputFill: inputFill,
                                  inputBorder: inputBorder,
                                  labelColor: primaryText,
                                  textColor: primaryText,
                                  readOnly: _fromGoogle,
                                ),
                                const SizedBox(height: 12),

                                _buildTextField(
                                  label: "Teléfono (Ecuador) *",
                                  controller: phoneController,
                                  hint:
                                      "+593 9XXXXXXXX / 09XXXXXXXX / 0[2-7]XXXXXXX",
                                  keyboardType: TextInputType.phone,
                                  night: night,
                                  inputFill: inputFill,
                                  inputBorder: inputBorder,
                                  labelColor: primaryText,
                                  textColor: primaryText,
                                ),
                                const SizedBox(height: 12),

                                _buildTextField(
                                  label: "Contraseña *",
                                  controller: passwordController,
                                  isPassword: true,
                                  hint: "Mínimo 6 caracteres",
                                  night: night,
                                  inputFill: inputFill,
                                  inputBorder: inputBorder,
                                  labelColor: primaryText,
                                  textColor: primaryText,
                                ),

                                const SizedBox(height: 18),

                                _AnimatedPrimaryButton(
                                  isLoading: _isLoading,
                                  onTap: _isLoading ? null : _handleRegister,
                                  label: "Registrarse",
                                ),

                                const SizedBox(height: 12),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "¿Ya tienes una cuenta?",
                                      style: TextStyle(
                                        color: secondaryText,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () {
                                        AppRoutes.navigateTo(
                                            context, AppRoutes.login);
                                      },
                                      child: const Text(
                                        "Inicia sesión",
                                        style: TextStyle(
                                          color: Color(0xFFE53935),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required bool night,
    required Color inputFill,
    required Color inputBorder,
    required Color labelColor,
    required Color textColor,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool readOnly = false,
  }) {
    final hintColor = const Color(0xFF9CA3AF);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: isPassword ? obscurePassword : false,
          readOnly: readOnly,
          // ✅ Recomendado para password (evita sugerencias/autocorrect y reduce fugas)
          enableSuggestions: !isPassword,
          autocorrect: !isPassword,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: hintColor),
            filled: true,
            fillColor: inputFill,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: const Color(0xFF9CA3AF),
                    ),
                    onPressed: () =>
                        setState(() => obscurePassword = !obscurePassword),
                  )
                : null,
          ),
        ),
      ],
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
                  maxWidth: 512,
                  maxHeight: 512,
                  imageQuality: 75,
                );
                if (image != null) {
                  setState(() {
                    _imageFile = File(image.path);
                    _googlePhotoUrl = null;
                  });
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
                  maxWidth: 512,
                  maxHeight: 512,
                  imageQuality: 75,
                );
                if (image != null) {
                  setState(() {
                    _imageFile = File(image.path);
                    _googlePhotoUrl = null;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRegister() async {
    final nombre = nameController.text.trim();
    final apellido = apellidoController.text.trim();
    final email = emailController.text.trim();
    final telefono = phoneController.text.trim();
    final pass = passwordController.text;

    if (nombre.isEmpty) return _showError('Por favor ingresa tu nombre');
    if (apellido.isEmpty) return _showError('Por favor ingresa tu apellido');

    if (email.isEmpty) return _showError('Por favor ingresa tu correo');
    if (!_isValidEmail(email)) {
      return _showError('Por favor ingresa un correo válido');
    }

    if (telefono.isEmpty) {
      return _showError('Por favor ingresa tu teléfono');
    }
    if (!_isValidEcuadorPhone(telefono)) {
      return _showError(
          'Teléfono inválido. Usa 09XXXXXXXX, 0[2-7]XXXXXXX o +593...');
    }

    if (pass.isEmpty) return _showError('Por favor ingresa una contraseña');
    if (pass.length < 6) {
      return _showError('La contraseña debe tener al menos 6 caracteres');
    }

    // ==========================
    // ✅ OFFLINE: NO registrar, pero guardar borrador
    // ==========================
    final hasInternet = await _hasInternetNow();
    if (!hasInternet) {
      await _saveDraft();
      _showOffline(
        "No tienes internet. Guardamos tu información para que no la pierdas. "
        "Conéctate y vuelve a intentar.",
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? fotoUrl;

      // Si el usuario eligió imagen manual -> Cloudinary
      if (_imageFile != null) {
        fotoUrl = await CloudinaryService.uploadImage(_imageFile!);
        if (fotoUrl == null) {
          _showError("No se pudo subir la foto. Inténtalo de nuevo.");
          return;
        }
      } else if (_googlePhotoUrl != null && _googlePhotoUrl!.trim().isNotEmpty) {
        // ✅ Si vino de Google y NO eligió imagen, usamos la url de Google
        fotoUrl = _googlePhotoUrl!.trim();
      }

      final result = await AuthService.registrar(
        nombre: nombre,
        apellido: apellido,
        email: email,
        telefono: telefono,
        password: pass,
        fotoUrl: fotoUrl,
      );

      if (result['success'] != true) {
        final rawMsg = (result['message'] ?? '').toString();
        final msgLower = rawMsg.toLowerCase();

        if (msgLower.contains('correo') && msgLower.contains('registr')) {
          _showError("Este correo ya está registrado. Por favor inicia sesión.");
        } else {
          _showError(rawMsg.isEmpty ? 'Error al registrar usuario' : rawMsg);
        }

        // guardamos borrador por si fue un fallo temporal
        await _saveDraft();
        return;
      }

      if (!mounted) return;

      // ✅ Si ya registró, limpiamos borrador
      await _draft.clear();

      _showSuccess("Registrado correctamente");

      await Future.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      AppRoutes.navigateAndClearStack(context, AppRoutes.communityPicker);
    } catch (_) {
      if (!mounted) return;

      // guardamos borrador si hubo excepción (backend caído, timeouts, etc.)
      await _saveDraft();

      _showError("No se pudo conectar. Verifica internet y backend.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveDraft() async {
    try {
      await _draft.save(
        name: nameController.text.trim(),
        apellido: apellidoController.text.trim(),
        email: emailController.text.trim(),
        telefono: phoneController.text.trim(),
        googlePhotoUrl: (_googlePhotoUrl?.trim().isNotEmpty ?? false) ? _googlePhotoUrl!.trim() : null,
        localImagePath: _imageFile?.path,
        fromGoogle: _fromGoogle,
      );
    } catch (_) {}
  }

  // ==========================
  // Google: prefill / login
  // ==========================
  Future<void> _handleGooglePrefill() async {
    if (_isGoogleLoading) return;

    // ✅ OFFLINE: Google requiere internet
    final hasInternet = await _hasInternetNow();
    if (!hasInternet) {
      await _saveDraft();
      _showOffline("No tienes internet. Conéctate para completar con Google.");
      return;
    }

    setState(() => _isGoogleLoading = true);

    try {
      // Limpieza sesiones anteriores
      try {
        await GoogleSignIn(serverClientId: _serverClientId).signOut();
      } catch (_) {}
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}

      final googleSignIn = GoogleSignIn(
        serverClientId: _serverClientId,
        scopes: const ["email", "profile", "openid"],
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        _showError("Inicio con Google cancelado");
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null || idToken.isEmpty) {
        _showError(
          "Google no devolvió idToken (revisa serverClientId / SHA1 / Play Services)",
        );
        return;
      }

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );

      try {
        await FirebaseAuth.instance.signInWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        _showError(AuthService.mapFirebaseAuthError(e));
        return;
      } catch (e) {
        _showError("Error Firebase (credential): $e");
        return;
      }

      // Llamamos backend: valida si ya existe en Supabase
      final result = await AuthService.loginWithFirebaseGoogle();

      // ===== CASO 1: YA ESTÁ REGISTRADO EN SAFEZONE (NO PERMITIR REGISTRO) =====
      if (result['success'] == true && result['registered'] == true) {
        // Cerramos sesión de Firebase/Google para no dejarla colgada
        try {
          await FirebaseAuth.instance.signOut();
        } catch (_) {}
        try {
          await GoogleSignIn(serverClientId: _serverClientId).signOut();
        } catch (_) {}

        _showError("Este correo ya está registrado. Por favor inicia sesión.");

        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;

        AppRoutes.navigateAndClearStack(context, AppRoutes.login);
        return;
      }

      // ===== CASO 2: Google OK, PERO FALTA REGISTRO LEGAL (nuevo usuario) =====
      if (result['registered'] == false) {
        final fbUser = FirebaseAuth.instance.currentUser;
        final email = (result['email'] ?? fbUser?.email ?? '').toString().trim();
        final name = (fbUser?.displayName ?? '').toString().trim();
        final picture = (fbUser?.photoURL ?? '').toString().trim();

        setState(() {
          _fromGoogle = true;
          _googlePhotoUrl = picture.isNotEmpty ? picture : null;
        });

        if (email.isNotEmpty && emailController.text.trim().isEmpty) {
          emailController.text = email;
        }

        if (name.isNotEmpty &&
            nameController.text.trim().isEmpty &&
            apellidoController.text.trim().isEmpty) {
          final parts = name.split(' ').where((e) => e.trim().isNotEmpty).toList();
          if (parts.isNotEmpty) {
            nameController.text = parts.first;
            if (parts.length > 1) {
              apellidoController.text = parts.sublist(1).join(' ');
            }
          }
        }

        await _saveDraft();
        _showSuccess("Correo verificado con Google, completa tus datos legales.");
        return;
      }

      _showError(
        (result['message'] ?? 'Error login Google (backend)').toString(),
      );
    } catch (e) {
      _showError("Error Google (general): $e");
      await _saveDraft();
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(email);
  }

  // ✅ Alineado con backend: móvil + fijo, local + E.164
  bool _isValidEcuadorPhone(String input) {
    final v = input
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .replaceAll('(', '')
        .replaceAll(')', '');

    final rMovilLocal = RegExp(r'^09\d{8}$');
    final rMovilE164 = RegExp(r'^\+5939\d{8}$');

    final rFijoLocal = RegExp(r'^0[2-7]\d{7}$');
    final rFijoE164 = RegExp(r'^\+593[2-7]\d{7}$');

    return rMovilLocal.hasMatch(v) ||
        rMovilE164.hasMatch(v) ||
        rFijoLocal.hasMatch(v) ||
        rFijoE164.hasMatch(v);
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

  void _showOffline(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.wifi_off_rounded, color: Colors.white),
            SizedBox(width: 10),
            // El Text real va abajo (Expanded)
          ],
        ),
        backgroundColor: const Color(0xFFB45309), // ámbar/aviso (no rojo)
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );

    // segunda SnackBar con texto completo (para que no se corte con el Row fijo)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFB45309),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(milliseconds: 900),
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
                color: const Color(0xFFE53935).withOpacity(0.45),
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

// ============================================================
// ✅ Borrador del registro (Hive)
// - NO guarda contraseña (por seguridad)
// - Solo mantiene campos para no perder el formulario
// ============================================================

class RegisterDraftData {
  final String? name;
  final String? apellido;
  final String? email;
  final String? telefono;
  final String? googlePhotoUrl;
  final String? localImagePath;
  final bool fromGoogle;
  final int updatedAtMillis;

  RegisterDraftData({
    required this.name,
    required this.apellido,
    required this.email,
    required this.telefono,
    required this.googlePhotoUrl,
    required this.localImagePath,
    required this.fromGoogle,
    required this.updatedAtMillis,
  });
}

class RegisterDraftCache {
  RegisterDraftCache._();
  static final RegisterDraftCache instance = RegisterDraftCache._();

  static const String boxName = 'sz_register_draft';

  static const String kName = 'name';
  static const String kApellido = 'apellido';
  static const String kEmail = 'email';
  static const String kTelefono = 'telefono';
  static const String kGooglePhotoUrl = 'googlePhotoUrl';
  static const String kLocalImagePath = 'localImagePath';
  static const String kFromGoogle = 'fromGoogle';
  static const String kUpdatedAt = 'updatedAt';

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    await Hive.openBox(boxName);
    _ready = true;
  }

  Box get _box => Hive.box(boxName);

  RegisterDraftData? read() {
    try {
      final any = _box.get(kUpdatedAt);
      if (any == null) return null;

      return RegisterDraftData(
        name: _box.get(kName) as String?,
        apellido: _box.get(kApellido) as String?,
        email: _box.get(kEmail) as String?,
        telefono: _box.get(kTelefono) as String?,
        googlePhotoUrl: _box.get(kGooglePhotoUrl) as String?,
        localImagePath: _box.get(kLocalImagePath) as String?,
        fromGoogle: (_box.get(kFromGoogle) as bool?) ?? false,
        updatedAtMillis: (_box.get(kUpdatedAt) as int?) ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save({
    required String? name,
    required String? apellido,
    required String? email,
    required String? telefono,
    required String? googlePhotoUrl,
    required String? localImagePath,
    required bool fromGoogle,
  }) async {
    await init();

    // evita guardar “basura” (todo vacío)
    final allEmpty = (name == null || name.trim().isEmpty) &&
        (apellido == null || apellido.trim().isEmpty) &&
        (email == null || email.trim().isEmpty) &&
        (telefono == null || telefono.trim().isEmpty) &&
        (googlePhotoUrl == null || googlePhotoUrl.trim().isEmpty) &&
        (localImagePath == null || localImagePath.trim().isEmpty);

    if (allEmpty) return;

    await _box.put(kName, name);
    await _box.put(kApellido, apellido);
    await _box.put(kEmail, email);
    await _box.put(kTelefono, telefono);
    await _box.put(kGooglePhotoUrl, googlePhotoUrl);
    await _box.put(kLocalImagePath, localImagePath);
    await _box.put(kFromGoogle, fromGoogle);
    await _box.put(kUpdatedAt, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> clear() async {
    await init();
    await _box.clear();
  }
}
