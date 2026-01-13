import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin localNotif =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
  'safezone_channel',
  'SafeZone Notifications',
  description: 'Notificaciones de SafeZone',
  importance: Importance.max,
);

/// Hooks opcionales para navegación (setea desde tu app)
/// Ejemplo en main():
///   setOnFcmData((data) => print(data));
void Function(Map<String, dynamic> data)? _onFcmData;
void setOnFcmData(void Function(Map<String, dynamic> data) handler) {
  _onFcmData = handler;
}

/// NECESARIO para recibir notificaciones cuando la app está cerrada
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // Importante: inicializar Firebase en background
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Si ya está inicializado, no pasa nada
  }

  await _showLocalNotification(message);
}

/// Inicializar local notifications + canal Android
Future<void> initializeLocalNotifications() async {
  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings =
      InitializationSettings(android: androidInit);

  await localNotif.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse resp) {
      // Si quieres manejar taps de notificación local aquí:
      // resp.payload (si envías payload)
    },
  );

  // Crear canal Android
  final androidPlugin = localNotif
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  if (androidPlugin != null) {
    await androidPlugin.createNotificationChannel(_androidChannel);
  }
}

/// Mostrar notificación en foreground/background (local)
Future<void> _showLocalNotification(RemoteMessage message) async {
  const AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
    'safezone_channel',
    'SafeZone Notifications',
    channelDescription: 'Notificaciones de SafeZone',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
  );

  final title = message.notification?.title ?? 'Alerta';
  final body = message.notification?.body ?? 'Nueva notificación';

  await localNotif.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    const NotificationDetails(android: androidDetails),
  );
}

/// Inicialización FCM (llamar desde main)
Future<void> initializeFCM() async {
  // Asegura local notifications lista
  await initializeLocalNotifications();

  final FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Permisos
  await messaging.requestPermission(alert: true, badge: true, sound: true);

  // Background handler
  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

  // Foreground: mostrar notificación local
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    await _showLocalNotification(message);

    // También puedes consumir la data en vivo
    final data = Map<String, dynamic>.from(message.data);
    if (_onFcmData != null && data.isNotEmpty) _onFcmData!(data);
  });

  // Tap cuando la app está en background
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    if (_onFcmData != null && data.isNotEmpty) _onFcmData!(data);
  });

  // Tap cuando la app estaba cerrada
  final initial = await messaging.getInitialMessage();
  if (initial != null) {
    final data = Map<String, dynamic>.from(initial.data);
    if (_onFcmData != null && data.isNotEmpty) _onFcmData!(data);
  }
}
