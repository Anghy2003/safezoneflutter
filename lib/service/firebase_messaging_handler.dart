import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin localNotif =
    FlutterLocalNotificationsPlugin();

/// NECESARIO para recibir notificaciones cuando la app está cerrada
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await _showLocalNotification(message);
}

/// Inicializar canal local
Future<void> initializeLocalNotifications() async {
  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings =
      InitializationSettings(android: androidInit);

  await localNotif.initialize(initSettings);
}

/// Mostrar notificación en foreground/background
Future<void> _showLocalNotification(RemoteMessage message) async {
  const AndroidNotificationDetails details = AndroidNotificationDetails(
    'safezone_channel',
    'SafeZone Notifications',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
  );

  await localNotif.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    message.notification?.title ?? 'Alerta',
    message.notification?.body ?? 'Nueva notificación',
    const NotificationDetails(android: details),
  );
}

/// Inicialización FCM (llamar desde main)
Future<void> initializeFCM() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  await messaging.requestPermission(alert: true, badge: true, sound: true);

  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    await _showLocalNotification(message);
  });
}
