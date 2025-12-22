import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:safezone_app/service/auth_service.dart';

import 'routes/app_routes.dart';
import 'service/sos_hardware_service.dart';

// 🔑 Clave global para navegación desde FCM
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 🔔 Plugin de notificaciones locales
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// =======================================================
/// HANDLER BACKGROUND FCM
/// (OBLIGATORIO @pragma PARA firebase_messaging ^15)
/// =======================================================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📩 Notificación en background: ${message.data}');
  await _showNotificationFromMessage(message);
}

/// =======================================================
/// INICIALIZAR NOTIFICACIONES LOCALES
/// =======================================================
Future<void> _initLocalNotifications() async {
  const AndroidInitializationSettings initSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings =
      InitializationSettings(android: initSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    // Si quisieras navegar al tocar la noti local, aquí va el callback
    // onDidReceiveNotificationResponse: (NotificationResponse response) {
    //   // parsear payload si lo usas
    // },
  );
}

/// =======================================================
/// MOSTRAR NOTIFICACIÓN LOCAL DESDE UN RemoteMessage FCM
/// =======================================================
Future<void> _showNotificationFromMessage(RemoteMessage message) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'safezone_channel', // id del canal
    'SafeZone Notifications', // nombre del canal
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
    payload: null,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Inicializar Firebase
  await Firebase.initializeApp();

  // 🔔 Inicializar notificaciones locales
  await _initLocalNotifications();
   await AuthService.restoreSession();

  // Registrar handler background para FCM
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 🆘 Inicializar canal nativo SOS
  await SosHardwareService.init();

  try {
    debugPrint('🟢 Iniciando servicio nativo de volumen (SOS)...');
    await SosHardwareService.startNativeService();
    debugPrint('✅ Servicio nativo de volumen iniciado correctamente');
  } catch (e) {
    debugPrint('❌ Error al iniciar servicio nativo de volumen: $e');
  }

  // 🔄 Solo vertical
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const SafeZoneApp());
}

class SafeZoneApp extends StatefulWidget {
  const SafeZoneApp({super.key});

  @override
  State<SafeZoneApp> createState() => _SafeZoneAppState();
}

class _SafeZoneAppState extends State<SafeZoneApp> {
  bool _tokenObtenido = false;

  @override
  void initState() {
    super.initState();

    // ✅ Configurar presentación de notificaciones en foreground (iOS/Android)
    FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 🔔 Notificación en FOREGROUND → mostramos notificación local
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('🔵 Notificación en foreground: ${message.data}');
      await _showNotificationFromMessage(message);
    });

    // 🔔 Notificación tocada desde BACKGROUND
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🟣 Notificación abierta desde background: ${message.data}');
      _handleNotificationTap(message.data);
    });

    // 🔔 App abierta completamente desde notificación (estando TERMINADA)
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        debugPrint(
            '🟠 App abierta desde terminada por notificación: ${message.data}');
        // Asegurarnos de navegar cuando ya exista el árbol de navegación
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleNotificationTap(message.data);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        // ✅ Token FCM solo UNA vez (para mostrarlo ahora en consola / pruebas)
        if (!_tokenObtenido) {
          _tokenObtenido = true;
          _obtenerTokenFCM(context);
        }

        return MaterialApp(
          title: 'SafeZone',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF5B9BD5),
            ),
            useMaterial3: true,
            fontFamily: 'Roboto',
          ),
          // 👇 Arranca en el SPLASH
          initialRoute: AppRoutes.splash,
          onGenerateRoute: AppRoutes.generateRoute,
        );
      },
    );
  }
}

/// ✅ Manejo de navegación desde notificación
void _handleNotificationTap(Map<String, dynamic> data) {
  debugPrint('➡️ Navegando a comunidad con data: $data');

  // Puede venir como "tipoNotificacion" o con otro casing
  final String tipo = (data['tipoNotificacion'] ??
          data['tipo_notificacion'] ??
          data['tipo'] ??
          '')
      .toString();

  // Determinar pestaña:
  // 0 = Comunidad (INCIDENTE_COMUNIDAD, CHAT_COMUNIDAD, etc.)
  // 1 = Cerca (INCIDENTE_VECINOS, CHAT_VECINOS, etc.)
  final int openTab =
      (tipo == 'INCIDENTE_VECINOS' || tipo == 'CHAT_VECINOS') ? 1 : 0;

  // Comunidad (por si quieres filtrarla después)
  final String? comunidadId =
      (data['comunidadId'] ?? data['comunidad_id'])?.toString();

  navigatorKey.currentState?.pushNamed(
    AppRoutes.community,
    arguments: {
      'openTab': openTab,
      'comunidadId': comunidadId,
    },
  );
}

/// ✅ Obtener token FCM (una sola vez) – ahora solo lo mostramos en consola
void _obtenerTokenFCM(BuildContext context) async {
  try {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    String? token = await messaging.getToken();

    if (token != null) {
      debugPrint("=========== TOKEN FCM ===========");
      debugPrint(token);
      debugPrint("=================================");

      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Token FCM generado (revisar consola)"),
            duration: Duration(seconds: 4),
          ),
        );
      });
    } else {
      debugPrint("⚠️ No se pudo obtener el token FCM");
    }
  } catch (e) {
    debugPrint("❌ Error al obtener token FCM: $e");
  }
}
