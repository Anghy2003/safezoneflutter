// lib/screens/login_screen.dart
import 'dart:async';
import 'dart:developer' as dev show log;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _cardOpacity;
  late final Animation<Offset> _cardOffset;

  static const String _serverClientId =
      "148831363300-1gmm6f3rls7pflfmk6dp6jm5cd601tqb.apps.googleusercontent.com";

  bool _isOnline = true;
  Timer? _netTimer;
  bool _netCheckRunning = false;

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

    _startInternetWatcher();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _autoRedirectIfSession();
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _controller.dispose();
    _netTimer?.cancel();
    super.dispose();
  }

  Future<bool> _hasInternet() async {
    try {
      final res = await InternetAddress.lookup('example.com')
          .timeout(const Duration(seconds: 2));
      return res.isNotEmpty && res.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _startInternetWatcher() {
    _refreshInternetStatus();
    _netTimer?.cancel();
    _netTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _refreshInternetStatus();
    });
  }

  Future<void> _refreshInternetStatus() async {
    if (_netCheckRunning) return;
    _netCheckRunning = true;

    try {
      final ok = await _hasInternet();
      if (!mounted) return;

      if (ok != _isOnline) {
        setState(() => _isOnline = ok);
      }
    } finally {
      _netCheckRunning = false;
    }
  }

  Future<bool> _ensureInternetOrSnack() async {
    if (!_isOnline) {
      _showSnack("No hay internet para entrar");
      return false;
    }

    final ok = await _hasInternet();
    if (!mounted) return false;

    if (!ok) {
      if (_isOnline) setState(() => _isOnline = false);
      _showSnack("No hay internet para entrar");
      return false;
    }

    if (!_isOnline) setState(() => _isOnline = true);
    return true;
  }

  Future<void> _autoRedirectIfSession() async {
    await AuthService.restoreSession();

    if (!mounted) return;
    if (!AuthService.hasLocalSession) return;

    final prefs = await SharedPreferences.getInstance();
    final communityId = prefs.getInt('communityId');

    if (!mounted) return;

    if (communityId == null) {
      AppRoutes.navigateAndClearStack(context, AppRoutes.communityPicker);
    } else {
      AppRoutes.navigateAndClearStack(context, AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bool keyboardOpen = media.viewInsets.bottom > 0;
    final bool isNightMode = Theme.of(context).brightness == Brightness.dark;

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

    final Color separatorColor =
        isNightMode ? const Color(0xFF111827) : const Color(0xFFE5E7EB);

    final Color googleTextColor = primaryText;
    final Color googleBorderColor = inputBorder;

    final Color cardShadowColor = isNightMode
        ? Colors.black.withOpacity(0.7)
        : Colors.black.withOpacity(0.06);

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              height: _isOnline ? 0 : 44,
              width: double.infinity,
              child: _isOnline
                  ? const SizedBox.shrink()
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935).withOpacity(0.95),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                            color: Colors.black.withOpacity(0.12),
                          ),
                        ],
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.wifi_off, color: Colors.white, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Sin conexión. Conéctate a internet para iniciar sesión.",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
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
                              controller: emailController,
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
                                  _showSnack(
                                      "Recuperación de contraseña pendiente");
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
                                  child: Container(
                                      height: 1, color: separatorColor),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                                  child: Text(
                                    "o continúa con",
                                    style: TextStyle(
                                      color: mutedText,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                      height: 1, color: separatorColor),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap:
                                  _isGoogleLoading ? null : _handleGoogleLogin,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 11),
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

  Future<void> _handleLogin() async {
    final can = await _ensureInternetOrSnack();
    if (!can) return;

    final email = emailController.text.trim();
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
      final msg = (result['message'] ?? 'Error al iniciar sesión').toString();
      if (msg.toLowerCase().contains('no hay conexión') ||
          msg.toLowerCase().contains('internet')) {
        _showSnack("No hay internet para entrar");
      } else {
        _showSnack(msg);
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    final can = await _ensureInternetOrSnack();
    if (!can) return;

    if (_isGoogleLoading) return;

    final swAll = Stopwatch()..start();
    setState(() => _isGoogleLoading = true);

    void L(String msg) => dev.log(msg, name: 'SAFEZONE_GOOGLE');

    try {
      L("STEP 0: start _handleGoogleLogin()");

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
      L("STEP 1: GoogleSignIn created");

      L("STEP 2: googleSignIn.signIn()...");
      final swSignIn = Stopwatch()..start();
      final googleUser = await googleSignIn.signIn();
      swSignIn.stop();

      if (googleUser == null) {
        L("STEP 2.1: canceled t=${swSignIn.elapsedMilliseconds}ms");
        _showSnack("Inicio con Google cancelado");
        return;
      }

      L("STEP 2.2: googleUser OK email=${googleUser.email} t=${swSignIn.elapsedMilliseconds}ms");

      L("STEP 3: googleUser.authentication...");
      final swAuth = Stopwatch()..start();
      final googleAuth = await googleUser.authentication;
      swAuth.stop();

      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null || idToken.isEmpty) {
        L("STEP 3.1: idToken NULL/EMPTY");
        _showSnack(
            "Google no devolvió idToken (revisa serverClientId / SHA1 / Play Services)");
        return;
      }

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );

      L("STEP 4: FirebaseAuth.signInWithCredential...");
      final swFb = Stopwatch()..start();
      UserCredential userCred;
      try {
        userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        L("STEP 4.1: FirebaseAuthException code=${e.code} msg=${e.message}");
        _showSnack(AuthService.mapFirebaseAuthError(e));
        return;
      } catch (e) {
        L("STEP 4.2: Firebase signInWithCredential ERROR: $e");
        _showSnack("Error Firebase (credential): $e");
        return;
      } finally {
        swFb.stop();
      }

      final fbUser = userCred.user;
      L("STEP 4.3: Firebase OK t=${swFb.elapsedMilliseconds}ms uid=${fbUser?.uid} email=${fbUser?.email}");

      L("STEP 5: AuthService.loginWithFirebaseGoogle()...");
      final swApi = Stopwatch()..start();
      final result = await AuthService.loginWithFirebaseGoogle();
      swApi.stop();

      L("STEP 5.1: backend result t=${swApi.elapsedMilliseconds}ms -> $result");

      final msgLower =
          (result['message'] ?? '').toString().toLowerCase().trim();
      if (msgLower.contains('no hay conexión') || msgLower.contains('internet')) {
        _showSnack("No hay internet para entrar");
        return;
      }

      if (result['success'] != true && result['registered'] == false) {
        final email = (result['email'] ?? googleUser.email).toString();
        final name = (googleUser.displayName ?? '').toString();
        final picture = (googleUser.photoUrl ?? '').toString();

        _showSnack(result['message']?.toString() ??
            "Tu correo fue verificado con Google. Completa el registro.");

        if (!mounted) return;

        AppRoutes.navigateTo(
          context,
          AppRoutes.register,
          arguments: {
            'email': email,
            'name': name,
            'picture': picture,
          },
        );
        return;
      }

      if (result['success'] == true) {
        L("STEP 6: _afterAuthSuccess()...");
        await _afterAuthSuccess(result);
      } else {
        _showSnack(
            result['message']?.toString() ?? "Error login Google (backend)");
      }
    } catch (e) {
      L("CATCH: unexpected ERROR: $e");
      final s = e.toString().toLowerCase();
      if (s.contains('socket') || s.contains('network')) {
        _showSnack("No hay internet para entrar");
      } else {
        _showSnack("Error Google (general): $e");
      }
    } finally {
      swAll.stop();
      L("FINALLY: total=${swAll.elapsedMilliseconds}ms _isGoogleLoading=false");
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  // =========================================================
  // ✅ Guarda: userId/communityId + userRole/isAdmin + userEmail/communityRole + flags
  // =========================================================
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

    dev.log(
      "LOGIN BACKEND → id=${usuario.id} email=${usuario.email} rol=${usuario.rol} comunidadId=${usuario.comunidadId}",
      name: "SAFEZONE_DEBUG",
    );

    // ✅ IDs
    if (usuario.id != null) {
      await prefs.setInt('userId', usuario.id!);
    }

    if (usuario.comunidadId != null) {
      await prefs.setInt('communityId', usuario.comunidadId!);
    } else {
      await prefs.remove('communityId');
    }

    // ✅ EMAIL (para SuperAdmin por correo)
    final email = (usuario.email ?? '').trim();
    if (email.isNotEmpty) {
      await prefs.setString('userEmail', email);
    } else {
      await prefs.remove('userEmail');
    }

    // ✅ rol comunidad (para drawer)
    final communityRole = (usuario.rol ?? 'USER').toUpperCase().trim();
    await prefs.setString('communityRole', communityRole);

    // ✅ compat: rol actual (tu UI)
    await prefs.setString('userRole', communityRole);
    await prefs.setBool('isAdmin', communityRole == 'ADMIN');

    // ✅ flags nuevos (menu/drawer)
    final isSuperAdmin =
        email.toLowerCase() == AuthService.superAdminEmail.toLowerCase();
    final isCommunityAdmin = communityRole == 'ADMIN';

    await prefs.setBool('isSuperAdmin', isSuperAdmin);
    await prefs.setBool('isCommunityAdmin', isCommunityAdmin);

    dev.log(
      "PREFS → userEmail=$email communityRole=$communityRole isSuperAdmin=$isSuperAdmin isCommunityAdmin=$isCommunityAdmin",
      name: "SAFEZONE_DEBUG",
    );

    await _registerFcmToken(userId: usuario.id);

    if (!mounted) return;

    if (usuario.comunidadId == null) {
      AppRoutes.navigateAndClearStack(context, AppRoutes.communityPicker);
    } else {
      AppRoutes.navigateAndClearStack(context, AppRoutes.home);
    }
  }

  Future<void> _registerFcmToken({int? userId}) async {
    try {
      if (userId == null) return;

      final fcm = FirebaseMessaging.instance;
      await fcm.requestPermission(alert: true, badge: true, sound: true);

      final token = await fcm.getToken();
      if (token == null || token.trim().isEmpty) return;

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