import 'package:flutter/material.dart';
import 'dart:ui'; // Necesario para el ImageFilter.blur

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Altura del iPhone X/11/12/13/14/15 bottom bar notch
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    // Altura total ajustada, la barra es más pequeña de 60 si no hay padding inferior
    // Usaremos un padding vertical superior mayor para subir la barra, como en tu imagen
    return ClipRRect(
      // Aplicamos el radio de borde aquí para que afecte al desenfoque también
      borderRadius: const BorderRadius.vertical(top: Radius.circular(44.15)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0), // Desenfoque sutil
        child: Container(
          // Altura base ajustada. Quitamos el SafeArea y lo manejamos con el padding inferior.
          height: 65 + bottomPadding, 
          padding: const EdgeInsets.only(top: 15), // Padding superior para subir los iconos
          decoration: BoxDecoration(
            // Color de fondo: 072446 al 15% de opacidad
            color: const Color(0xFF072446).withOpacity(0.15),
            // Los bordes redondeados se manejan con ClipRRect
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    icon: Icons.home,
                    label: 'Home',
                    index: 0,
                    activeColor: const Color(0xFF007BFF), // Azul activo
                    inactiveColor: Colors.white, // Inactivo blanco
                  ),
                  _buildNavItem(
                    icon: Icons.contact_mail,
                    label: 'Contactos',
                    index: 1,
                    activeColor: const Color(0xFF007BFF),
                    inactiveColor: Colors.white,
                  ),
                  _buildNavItem(
                    icon: Icons.explore,
                    label: 'Explore',
                    index: 2,
                    activeColor: const Color(0xFF007BFF),
                    inactiveColor: Colors.white,
                  ),
                  _buildNavItem(
                    icon: Icons.person,
                    label: 'Perfil',
                    index: 3,
                    activeColor: const Color(0xFF007BFF),
                    inactiveColor: Colors.white,
                  ),
                ],
              ),
              // Espacio para la barra inferior del iPhone (el notch)
              if (bottomPadding > 0)
                Container(
                  height: bottomPadding,
                  color: Colors.transparent, 
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    final bool isActive = currentIndex == index;
    final Color color = isActive ? activeColor : inactiveColor;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: color,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}