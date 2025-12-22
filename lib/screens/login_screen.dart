// lib/screens/login_screen.dart
import 'dart:developer' as dev show log;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../routes/app_routes.dart';
import '../service/auth_service.dart';
import '../models/usuario.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController cedulaController = TextEditingController(); // email
  final TextEditingController passwordController = TextEditingController();

  bool obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _cardOpacity;
  late final Animation<Offset> _cardOffset;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
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

    _cardOffset = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    cedulaController.dispose();
    passwordController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bool keyboardOpen = media.viewInsets.bottom > 0;

    final hour = DateTime.now().hour;
    final bool isNightMode = hour >= 19 || hour < 6;

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
    final Color separatorColor =
        isNightMode ? const Color(0xFF111827) : const Color(0xFFE5E7EB);
    final Color googleTextColor =
        isNightMode ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
    final Color googleBorderColor =
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.arrow_back_ios_new,
                        color: headerIconColor,
                        size: 20,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          "Alarma de emergencia",
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),
                    if (!keyboardOpen)
                      AnimatedBuilder(
                        animation: _logoScale,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _logoScale.value,
                            child: child,
                          );
                        },
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [
                                Color(0xFFFF6B6B),
                                Color(0xFFE53935),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE53935)
                                    .withOpacity(0.45),
                                blurRadius: 22,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Image.asset(
                              "assets/images/logoblanco.png",
                              width: 52,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    if (!keyboardOpen) const SizedBox(height: 18),
                    if (!keyboardOpen)
                      Text(
                        "Welcome back",
                        style: TextStyle(
                          color: primaryText,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (!keyboardOpen) const SizedBox(height: 6),
                    if (!keyboardOpen)
                      Text(
                        "Conéctate para mantener tu zona segura.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: secondaryText,
                          fontSize: 13,
                        ),
                      ),
                    const SizedBox(height: 22),

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
                              "Iniciar sesión",
                              style: TextStyle(
                                color: primaryText,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Ingresa tus datos para continuar con SafeZone.",
                              style: TextStyle(
                                color: mutedText,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 18),

                            Text(
                              "Correo electrónico",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isNightMode
                                    ? const Color(0xFFE5E7EB)
                                    : const Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: cedulaController,
                              keyboardType: TextInputType.emailAddress,
                              style: TextStyle(color: primaryText),
                              decoration: _inputDecoration(
                                hint: "Ingresa tu correo",
                                icon: Icons.mail_outline_rounded,
                                inputFill: inputFill,
                                inputBorder: inputBorder,
                              ),
                            ),

                            const SizedBox(height: 16),

                            Text(
                              "Contraseña",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isNightMode
                                    ? const Color(0xFFE5E7EB)
                                    : const Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: passwordController,
                              obscureText: obscurePassword,
                              style: TextStyle(color: primaryText),
                              decoration: _inputDecoration(
                                hint: "Ingresa tu contraseña",
                                icon: Icons.lock_outline_rounded,
                                inputFill: inputFill,
                                inputBorder: inputBorder,
                              ).copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                    color: mutedText,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      obscurePassword = !obscurePassword;
                                    });
                                  },
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  // TODO: recuperar contraseña
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  "¿Olvidaste tu contraseña?",
                                  style: TextStyle(
                                    color: Color(0xFFE53935),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            _AnimatedPrimaryButton(
                              isLoading: _isLoading,
                              onTap: _isLoading ? null : _handleLogin,
                              label: "Iniciar sesión",
                            ),

                            const SizedBox(height: 18),

                            Row(
                              children: [
                                Expanded(
                                  child: Container(height: 1, color: separatorColor),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Text(
                                    "o continúa con",
                                    style: TextStyle(
                                      color: mutedText,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(height: 1, color: separatorColor),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            GestureDetector(
                              onTap: _isGoogleLoading ? null : _handleGoogleLogin,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                decoration: BoxDecoration(
                                  color: isNightMode
                                      ? const Color(0xFF111827)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: googleBorderColor),
                                  boxShadow: [
                                    if (!isNightMode)
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_isGoogleLoading)
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    else ...[
                                      Image.asset(
                                        "assets/images/google.png",
                                        width: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Continuar con Google",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: googleTextColor,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "¿No tienes una cuenta?",
                                  style: TextStyle(
                                    color: secondaryText,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const _RegisterLink(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE53935), width: 2),
      ),
    );
  }

  // ===========================
  // LOGIN LOCAL (email/password) -> /api/usuarios/login
  // ===========================
  Future<void> _handleLogin() async {
    final email = cedulaController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty) return _showSnack('Por favor ingresa tu correo');
    if (password.isEmpty) return _showSnack('Por favor ingresa tu contraseña');

    setState(() => _isLoading = true);

    final result = await AuthService.login(email: email, password: password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      await _afterAuthSuccess(result);
    } else {
      _showSnack((result['message'] ?? 'Error al iniciar sesión').toString());
    }
  }

  // ===========================
  // LOGIN GOOGLE (Firebase) -> /api/usuarios/google-login
  // ===========================

Future<void> _handleGoogleLogin() async {
  if (_isGoogleLoading) return;

  final swAll = Stopwatch()..start();
  setState(() => _isGoogleLoading = true);

  void L(String msg) => dev.log(msg, name: 'SAFEZONE_GOOGLE');

  try {
    L("STEP 0: start _handleGoogleLogin()");

    // 0) Estado previo
    final prev = FirebaseAuth.instance.currentUser;
    L("STEP 0.1: Firebase currentUser BEFORE = ${prev?.uid} email=${prev?.email}");

    // 1) Construir GoogleSignIn con serverClientId (web client id)
    final googleSignIn = GoogleSignIn(
      serverClientId:
          "148831363300-1gmm6f3rls7pflfmk6dp6jm5cd601tqb.apps.googleusercontent.com",
      scopes: const ["email", "profile", "openid"],
    );
    L("STEP 1: GoogleSignIn created (serverClientId set)");

    // 2) SignOut previo por si quedó sesión rara
    try {
      await googleSignIn.signOut();
      L("STEP 2: googleSignIn.signOut() OK");
    } catch (e) {
      L("STEP 2: googleSignIn.signOut() ERROR: $e (ignorable)");
    }

    // 3) Abrir UI de Google
    L("STEP 3: calling googleSignIn.signIn()...");
    final swSignIn = Stopwatch()..start();
    final googleUser = await googleSignIn.signIn();
    swSignIn.stop();

    if (googleUser == null) {
      L("STEP 3.1: googleUser == null -> user canceled. t=${swSignIn.elapsedMilliseconds}ms");
      _showSnack("Inicio con Google cancelado");
      return;
    }

    L("STEP 3.2: googleUser OK: email=${googleUser.email} id=${googleUser.id} "
      "displayName=${googleUser.displayName} t=${swSignIn.elapsedMilliseconds}ms");

    // 4) Tokens Google
    L("STEP 4: requesting googleUser.authentication ...");
    final swAuth = Stopwatch()..start();
    final googleAuth = await googleUser.authentication;
    swAuth.stop();

    L("STEP 4.1: googleAuth received t=${swAuth.elapsedMilliseconds}ms "
      "hasIdToken=${googleAuth.idToken != null} hasAccessToken=${googleAuth.accessToken != null}");

    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null || idToken.isEmpty) {
      L("STEP 4.2: idToken is NULL/EMPTY -> Google did not return idToken. STOP.");
      _showSnack("Google no devolvió idToken (revisa serverClientId / SHA1 / Play Services)");
      return;
    }

    // (No imprimir el token completo por seguridad)
    L("STEP 4.3: idToken length=${idToken.length} (OK)");

    // 5) Login Firebase con credential
    final credential = GoogleAuthProvider.credential(
      idToken: idToken,
      accessToken: accessToken,
    );

    L("STEP 5: FirebaseAuth.signInWithCredential() ...");
    final swFb = Stopwatch()..start();
    UserCredential userCred;
    try {
      userCred = await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      L("STEP 5.1: FirebaseAuthException code=${e.code} msg=${e.message}");
      _showSnack(AuthService.mapFirebaseAuthError(e));
      return;
    } catch (e) {
      L("STEP 5.2: Firebase signInWithCredential unknown ERROR: $e");
      _showSnack("Error Firebase (credential): $e");
      return;
    } finally {
      swFb.stop();
    }

    final fbUser = userCred.user;
    L("STEP 5.3: Firebase signIn OK t=${swFb.elapsedMilliseconds}ms uid=${fbUser?.uid} email=${fbUser?.email}");

    // 6) Firebase ID token (el que tu backend debería aceptar)
    L("STEP 6: requesting Firebase ID token ...");
    final swId = Stopwatch()..start();
    final fbIdToken = await fbUser?.getIdToken(true);
    swId.stop();

    if (fbIdToken == null || fbIdToken.isEmpty) {
      L("STEP 6.1: Firebase getIdToken returned NULL/EMPTY (bad). t=${swId.elapsedMilliseconds}ms");
      _showSnack("Firebase no devolvió ID token. Revisa configuración Google Sign-In.");
      return;
    }

    L("STEP 6.2: Firebase ID token length=${fbIdToken.length} t=${swId.elapsedMilliseconds}ms");

    // 7) Backend login
    L("STEP 7: calling AuthService.loginWithFirebaseGoogle() ...");
    final swApi = Stopwatch()..start();
    final result = await AuthService.loginWithFirebaseGoogle();
    swApi.stop();

    L("STEP 7.1: backend result t=${swApi.elapsedMilliseconds}ms -> $result");

    if (result['success'] == true) {
      L("STEP 8: _afterAuthSuccess() ...");
      final swAfter = Stopwatch()..start();
      await _afterAuthSuccess(result);
      swAfter.stop();
      L("STEP 8.1: _afterAuthSuccess OK t=${swAfter.elapsedMilliseconds}ms");
    } else {
      L("STEP 8.2: backend returned success=false. message=${result['message']}");
      _showSnack(result['message']?.toString() ?? "Error login Google (backend)");
    }
  } catch (e) {
    L("CATCH: unexpected ERROR: $e");
    _showSnack("Error Google (general): $e");
  } finally {
    swAll.stop();
    L("FINALLY: total=${swAll.elapsedMilliseconds}ms _isGoogleLoading -> false");
    if (mounted) setState(() => _isGoogleLoading = false);
  }
}

  // ===========================
  // POST LOGIN: prefs + FCM + rutas
  // ===========================
  Future<void> _afterAuthSuccess(Map<String, dynamic> result) async {
    final prefs = await SharedPreferences.getInstance();

    final dynamic usuarioDyn = result['usuario'] ?? result['data'];
    if (usuarioDyn == null) {
      _showSnack('Respuesta inválida del servidor');
      return;
    }

    late final Usuario usuario;
    if (usuarioDyn is Usuario) {
      usuario = usuarioDyn;
    } else if (usuarioDyn is Map<String, dynamic>) {
      usuario = Usuario.fromJson(usuarioDyn);
    } else {
      _showSnack('Formato de usuario no reconocido');
      return;
    }

    // (Redundante pero ok): AuthService ya guarda userId/communityId internamente
    if (usuario.id != null) {
      await prefs.setInt('userId', usuario.id!);
    }

    if (usuario.comunidadId != null) {
      await prefs.setInt('communityId', usuario.comunidadId!);
    } else {
      await prefs.remove('communityId');
    }

    await _registerFcmToken(userId: usuario.id);

    if (!mounted) return;

    if (usuario.comunidadId == null) {
      AppRoutes.navigateAndClearStack(context, AppRoutes.verifyCommunity);
    } else {
      AppRoutes.navigateAndClearStack(context, AppRoutes.home);
    }
  }

  // ===========================
  // FCM TOKEN -> /api/usuarios/{id}/fcm-token usando AuthService.headers
  // ===========================
  Future<void> _registerFcmToken({int? userId}) async {
    try {
      if (userId == null) return;

      final fcm = FirebaseMessaging.instance;
      await fcm.requestPermission(alert: true, badge: true, sound: true);

      final token = await fcm.getToken();
      if (token == null || token.trim().isEmpty) return;

      // ✅ Un solo método, la cabecera sale de AuthService.headers (Bearer o X-User-Id)
      final res = await AuthService.updateFcmToken(
        userId: userId,
        token: token,
        deviceInfo: 'flutter',
      );

      if (res['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcmToken', token);
      }
    } catch (e) {
      debugPrint("Error registrando FCM token: $e");
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// Botón rojo animado tipo apps 2025
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
        builder: (context, child) {
          return Transform.scale(scale: _scale.value, child: child);
        },
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

/// Link de registro
class _RegisterLink extends StatelessWidget {
  const _RegisterLink();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppRoutes.navigateTo(context, AppRoutes.register);
      },
      child: const Text(
        "Regístrate",
        style: TextStyle(
          color: Color(0xFFE53935),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
