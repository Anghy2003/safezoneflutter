// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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

  late final AnimationController _controller;
  late final Animation<double> _avatarScale;
  late final Animation<double> _cardOpacity;
  late final Animation<Offset> _cardOffset;

  @override
  void initState() {
    super.initState();

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
  }

  @override
  void dispose() {
    nameController.dispose();
    apellidoController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool get isNightMode {
    final hour = DateTime.now().hour;
    return hour >= 19 || hour < 6;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    final bool night = isNightMode;
    final Color bgColor =
        night ? const Color(0xFF05070A) : const Color(0xFFF3F4F6);
    final Color cardColor = night ? const Color(0xFF0B1016) : Colors.white;
    final Color primaryText =
        night ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
    final Color secondaryText =
        night ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final Color inputFill =
        night ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    final Color inputBorder =
        night ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
    final Color headerIconColor =
        night ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
    final Color headerMuteIconColor =
        night ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);
    final Color cardShadowColor =
        night ? Colors.black.withOpacity(0.7) : Colors.black.withOpacity(0.06);

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                    // HEADER
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 10,
                      ),
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

                    // AVATAR
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
                                            .withOpacity(0.5),
                                        blurRadius: 18,
                                        spreadRadius: 3,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 46,
                                    backgroundColor: Colors.white,
                                    backgroundImage: _imageFile != null
                                        ? FileImage(_imageFile!)
                                        : null,
                                    child: _imageFile == null
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
                                          color: Colors.black.withOpacity(0.25),
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

                    // CARD FORM
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
                              "Registro legal en SafeZone (Ecuador).",
                              style: TextStyle(
                                color: secondaryText,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 16),

                            _buildTextField(
                              label: "Nombre *",
                              controller: nameController,
                              hint: "Ingresa tu nombre",
                              isNightMode: night,
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
                              isNightMode: night,
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
                              isNightMode: night,
                              inputFill: inputFill,
                              inputBorder: inputBorder,
                              labelColor: primaryText,
                              textColor: primaryText,
                            ),
                            const SizedBox(height: 12),

                            _buildTextField(
                              label: "Teléfono (Ecuador) *",
                              controller: phoneController,
                              hint: "+593 9XXXXXXXX o 09XXXXXXXX",
                              keyboardType: TextInputType.phone,
                              isNightMode: night,
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
                              isNightMode: night,
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
                                    AppRoutes.navigateTo(context, AppRoutes.login);
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
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required bool isNightMode,
    required Color inputFill,
    required Color inputBorder,
    required Color labelColor,
    required Color textColor,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
  }) {
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
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
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
                    onPressed: () {
                      setState(() => obscurePassword = !obscurePassword);
                    },
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
                  maxWidth: 512,
                  maxHeight: 512,
                  imageQuality: 75,
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

  Future<void> _handleRegister() async {
    final nombre = nameController.text.trim();
    final apellido = apellidoController.text.trim();
    final email = emailController.text.trim();
    final telefono = phoneController.text.trim();
    final pass = passwordController.text;

    if (nombre.isEmpty) return _showError('Por favor ingresa tu nombre');
    if (apellido.isEmpty) return _showError('Por favor ingresa tu apellido');

    if (email.isEmpty) return _showError('Por favor ingresa tu correo');
    if (!_isValidEmail(email)) return _showError('Por favor ingresa un correo válido');

    if (telefono.isEmpty) return _showError('Por favor ingresa tu teléfono');
    if (!_isValidEcuadorPhone(telefono)) {
      return _showError('Teléfono inválido. Usa +593 9XXXXXXXX o 09XXXXXXXX');
    }

    if (pass.isEmpty) return _showError('Por favor ingresa una contraseña');
    if (pass.length < 6) return _showError('La contraseña debe tener al menos 6 caracteres');

    setState(() => _isLoading = true);

    try {
      // 1) Foto a Cloudinary (opcional)
      String? fotoUrl;
      if (_imageFile != null) {
        fotoUrl = await CloudinaryService.uploadImage(_imageFile!);
        if (fotoUrl == null) {
          _showError("No se pudo subir la foto. Inténtalo de nuevo.");
          return;
        }
      }

      // 2) Registro LEGAL en backend (Supabase)
      final result = await AuthService.registrar(
        nombre: nombre,
        apellido: apellido,
        email: email,
        telefono: telefono,
        password: pass,
        fotoUrl: fotoUrl,
      );

      if (result['success'] != true) {
        _showError((result['message'] ?? 'Error al registrar usuario').toString());
        return;
      }

      if (!mounted) return;

      // Si quieres: ir a login
      AppRoutes.navigateAndClearStack(context, AppRoutes.login);

      // Si en tu flujo primero verificas comunidad, cambia a:
      // AppRoutes.navigateAndClearStack(context, AppRoutes.verifyCommunity);

    } catch (_) {
      if (!mounted) return;
      _showError("No se pudo conectar. Verifica internet y backend.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(email);
  }

  /// Ecuador:
  /// - Celular local: 09XXXXXXXX (10 dígitos)
  /// - E164: +5939XXXXXXXX (12-13 con +)
  bool _isValidEcuadorPhone(String input) {
    final v = input.replaceAll(' ', '').replaceAll('-', '');
    final r1 = RegExp(r'^09\d{8}$'); // 09 + 8 = 10
    final r2 = RegExp(r'^\+5939\d{8}$'); // +5939 + 8 = 12(+)
    return r1.hasMatch(v) || r2.hasMatch(v);
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
