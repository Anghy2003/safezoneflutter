import 'package:flutter/material.dart';

// 👇 IMPORTA TU SPLASH
import 'package:safezone_app/screens/SplashScreen.dart';

import 'package:safezone_app/screens/WelcomeScreen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/verify_community_screen.dart';
import '../screens/verify_success_screen.dart';
import '../screens/home_screen.dart';
import '../screens/contacts_screen.dart';
import '../screens/explore/explore_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/emergency_report_screen.dart';
import '../screens/community_screen.dart';
import '../screens/create_community_screen.dart';

class AppRoutes {
  // 👇 Asegura que splash sea la ruta raíz
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String verifyCommunity = '/verify-community';
  static const String verifySuccess = '/verify-success';
  static const String home = '/home';
  static const String contacts = '/contacts';
  static const String explore = '/explore';
  static const String profile = '/profile';
  static const String community = '/community';
  static const String createCommunity = '/create-community';
  static const String welcome = '/welcome';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    Widget page;

    switch (settings.name) {
      // 🔥 NUEVO: Splash
      case splash:
        page = const SplashScreen();
        break;

      case login:
        page = const LoginScreen();
        break;

      case register:
        page = const RegisterScreen();
        break;

      case verifyCommunity:
        page = const VerifyCommunityScreen();
        break;

      case verifySuccess:
        page = const VerifySuccessScreen();
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
        page = const ProfileScreen();
        break;

      case community:
        page = const CommunityScreen();
        break;

      case createCommunity:
        page = const CreateCommunityScreen();
        break;

      case welcome:
        page = const WelcomeScreen();
        break;

      // ⛔ DEFAULT → Splash
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

  static void navigateTo(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    Navigator.pushNamed(
      context,
      routeName,
      arguments: arguments,
    );
  }

  static void navigateAndReplace(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    Navigator.pushReplacementNamed(
      context,
      routeName,
      arguments: arguments,
    );
  }

  static void navigateAndClearStack(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }

  static void goBack(BuildContext context) {
    Navigator.pop(context);
  }
}
