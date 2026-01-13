// lib/routes/app_routes.dart
import 'package:flutter/material.dart';

import 'package:safezone_app/controllers/theme_controller.dart';
import 'package:safezone_app/service/theme_pref_service.dart';

import 'package:safezone_app/screens/SplashScreen.dart';
import 'package:safezone_app/screens/WelcomeScreen.dart';

import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/home_screen.dart';
import '../screens/contacts_screen.dart';
import '../screens/explore/explore_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/community_screen.dart';
import '../screens/create_community_screen.dart';

import '../screens/community_picker_screen.dart';
import '../screens/admin_panel_screen.dart';
import '../screens/admin_requests_screen.dart';

import '../screens/my_communities_screen.dart';
import '../screens/request_join_community_screen.dart';

// ✅ Menú completo
import '../screens/safezone_menu_screen.dart';

// ✅ Notificaciones
import '../screens/notifications_screen.dart';

// ✅ NUEVO: Políticas de uso + Penalización
import '../screens/usage_policies_screen.dart';
import '../screens/penalized_screen.dart';

class AppRoutes {
  // ---------------- Core / Arranque ----------------
  static const String splash = '/';
  static const String welcome = '/welcome';

  // ✅ NUEVO: Gate de políticas y penalización
  static const String policies = '/policies';
  static const String penalized = '/penalized';

  // ---------------- Auth ----------------
  static const String login = '/login';
  static const String register = '/register';

  // ---------------- Menú (pantalla completa) ----------------
  static const String menu = '/menu';

  // ---------------- Navegación principal ----------------
  static const String home = '/home';
  static const String contacts = '/contacts';
  static const String explore = '/explore';
  static const String profile = '/profile';

  // ---------------- Comunidades ----------------
  static const String community = '/community';
  static const String createCommunity = '/create-community';

  static const String communityPicker = '/community-picker';
  static const String requestJoinCommunity = '/request-join-community';
  static const String myCommunities = '/my-communities';

  // ✅ Admin de comunidad: SOLO solicitudes
  static const String communityAdminRequests = '/community-admin-requests';

  // ---------------- Admin global ----------------
  static const String admin = '/admin';

  // ✅ Notificaciones
  static const String notifications = '/notifications';

  static late ThemeController themeController;

  static Future<void> init() async {
    final tc = ThemeController(ThemePrefService());
    await tc.load();
    themeController = tc;
  }

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final args = settings.arguments;
    final Map a = (args is Map) ? args : const {};

    late final Widget page;

    switch (settings.name) {
      case splash:
        page = const SplashScreen();
        break;

      // ✅ NUEVO: Pantalla políticas
      case policies:
        page = const UsagePoliciesScreen();
        break;

      // ✅ NUEVO: Pantalla penalización
      case penalized:
        page = const PenalizedScreen();
        break;

      case welcome:
        page = const WelcomeScreen();
        break;

      case login:
        page = const LoginScreen();
        break;

      case register:
        page = const RegisterScreen();
        break;

      // ✅ Menú completo
      case menu:
        page = Builder(
          builder: (context) {
            final night = Theme.of(context).brightness == Brightness.dark;
            return SafeZoneMenuScreen(
              night: night,
              photoUrl: a["photoUrl"] as String?,
              displayName: a["displayName"] as String?,
            );
          },
        );
        break;

      case home:
        page = const HomeScreen();
        break;

      case contacts:
        page = const ContactsScreen();
        break;

      case explore:
        page = const ExploreScreen();
        break;

      case profile:
        page = ProfileScreen(themeController: themeController);
        break;

      // ---------------- Comunidades ----------------
      case communityPicker:
        page = const CommunityPickerScreen();
        break;

      case requestJoinCommunity:
        page = const RequestJoinCommunityScreen();
        break;

      case myCommunities:
        page = const MyCommunitiesScreen();
        break;

      case community:
        page = const CommunityScreen();
        break;

      case createCommunity:
        page = const CreateCommunityScreen();
        break;

      // ---------------- Admin ----------------
      case admin:
        page = const AdminPanelScreen();
        break;

      case communityAdminRequests:
        page = const AdminRequestsScreen();
        break;

      // ✅ Notificaciones (requiere comunidadId)
      case notifications:
        final int comunidadId = (a["comunidadId"] is num)
            ? (a["comunidadId"] as num).toInt()
            : 0;

        // Si llega mal, manda al picker (evita crash)
        if (comunidadId <= 0) {
          page = const CommunityPickerScreen();
        } else {
          page = NotificationsScreen(comunidadId: comunidadId);
        }
        break;

      default:
        page = const SplashScreen();
    }

    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  static void navigateTo(BuildContext context, String routeName,
      {Object? arguments}) {
    Navigator.pushNamed(context, routeName, arguments: arguments);
  }

  static void navigateAndReplace(BuildContext context, String routeName,
      {Object? arguments}) {
    Navigator.pushReplacementNamed(context, routeName, arguments: arguments);
  }

  static void navigateAndClearStack(BuildContext context, String routeName,
      {Object? arguments}) {
    Navigator.pushNamedAndRemoveUntil(context, routeName, (route) => false,
        arguments: arguments);
  }

  static void goBack(BuildContext context) => Navigator.pop(context);
}
