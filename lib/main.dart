// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ✅ FMTC (tiles offline)
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

import 'routes/app_routes.dart';
import 'service/auth_service.dart';
import 'service/sos_hardware_service.dart';
import 'offline/offline_bootstrap.dart';

// 🔑 Clave global para navegación desde FCM (y desde Tile)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await _initLocalNotifications();
  await _showNotificationFromMessage(message);
}

Future<void> _initLocalNotifications() async {
  const AndroidInitializationSettings initSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings =
      InitializationSettings(android: initSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'safezone_channel',
    'SafeZone Notifications',
    description: 'Notificaciones de incidentes y alertas',
    importance: Importance.max,
  );

  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  await androidPlugin?.createNotificationChannel(channel);
  await androidPlugin?.requestNotificationsPermission(); // ✅ Android 13+
}

Future<void> _showNotificationFromMessage(RemoteMessage message) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'safezone_channel',
    'SafeZone Notifications',
    channelDescription: 'Notificaciones de incidentes y alertas',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
  );

  const NotificationDetails platformDetails =
      NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    message.notification?.title ?? 'Alerta',
    message.notification?.body ?? 'Tienes una nueva notificación',
    platformDetails,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  await _initLocalNotifications();

  // ✅ OFFLINE: cola + listener conectividad + sync
  await OfflineBootstrap.ensureInitialized();

  // ✅ FMTC: inicializa backend (ObjectBox) y crea el store de tiles UNA VEZ
  await FMTCObjectBoxBackend().initialise(); // v10+ :contentReference[oaicite:1]{index=1}
  final tilesStore = FMTCStore('safezone_tiles');
  try {
    await tilesStore.manage.create(); // :contentReference[oaicite:2]{index=2}
  } catch (_) {
    // si ya existe, ignora
  }

  // ✅ Restaura sesión local (NO limpia)
  await AuthService.restoreSession();

  // ✅ ThemeController global
  await AppRoutes.init();

  // ✅ Decide ruta inicial real (mantener sesión aunque no haya internet)
  final initialRoute = await AuthService.computeInitialRoute();

  // ✅ Handler background FCM
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ✅ SOS Tile → Flutter
  await SosHardwareService.init();
  SosHardwareService.bindNavigator(navigatorKey);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(SafeZoneApp(initialRoute: initialRoute));
}

class SafeZoneApp extends StatefulWidget {
  final String initialRoute;
  const SafeZoneApp({super.key, required this.initialRoute});

  @override
  State<SafeZoneApp> createState() => _SafeZoneAppState();
}

class _SafeZoneAppState extends State<SafeZoneApp> {
  bool _tokenObtenido = false;

  @override
  void initState() {
    super.initState();

    _requestNotifPermission();

    FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((message) async {
      await _showNotificationFromMessage(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationTap(message.data);
    });

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleNotificationTap(message.data);
        });
      }
    });

    _ensureFcmToken();
  }

  Future<void> _requestNotifPermission() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _ensureFcmToken() async {
    if (_tokenObtenido) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    if (!mounted) return;
    setState(() => _tokenObtenido = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppRoutes.themeController,
      builder: (_, __) {
        return MaterialApp(
          title: 'SafeZone',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          themeMode: AppRoutes.themeController.mode,
          theme: ThemeData(
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF5B9BD5),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            fontFamily: 'Roboto',
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF5B9BD5),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            fontFamily: 'Roboto',
          ),
          initialRoute: widget.initialRoute,
          onGenerateRoute: AppRoutes.generateRoute,
        );
      },
    );
  }
}

void _handleNotificationTap(Map<String, dynamic> data) {
  final String tipo =
      (data['tipoNotificacion'] ?? data['tipo_notificacion'] ?? data['tipo'] ?? '')
          .toString();

  final int openTab =
      (tipo == 'INCIDENTE_VECINOS' || tipo == 'CHAT_VECINOS') ? 1 : 0;

  final String? comunidadId =
      (data['comunidadId'] ?? data['comunidad_id'])?.toString();

  navigatorKey.currentState?.pushNamed(
    AppRoutes.community,
    arguments: {'openTab': openTab, 'comunidadId': comunidadId},
  );
}
