import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';

class SafeZoneNavBar extends StatelessWidget {
  final int currentIndex;
  final bool isNightMode;
  final double bottomPadding;
  final ValueChanged<int> onTap;

  const SafeZoneNavBar({
    super.key,
    required this.currentIndex,
    required this.isNightMode,
    required this.bottomPadding,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color barColor =
        isNightMode ? const Color(0xFF181A24) : Colors.white;

    return Positioned(
      left: 14,
      right: 14,
      bottom: bottomPadding + 18,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            if (!isNightMode)
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 24,
                offset: const Offset(0, 10),
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(0.60),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: CurvedNavigationBar(
          index: currentIndex,
          height: 64, // un poquito más alto
          backgroundColor: Colors.transparent,
          color: barColor,
          buttonBackgroundColor: const Color(0xFFFF5A5F),
          animationCurve: Curves.easeOutCubic,
          animationDuration: const Duration(milliseconds: 320),
          items: [
            _navIcon(
              icon: Icons.home_rounded,
              itemIndex: 0,
            ),
            _navIcon(
              icon: Icons.contacts_rounded,
              itemIndex: 1,
            ),
            _navIcon(
              icon: Icons.explore_rounded,
              itemIndex: 2,
            ),
            _navIcon(
              icon: Icons.forum_rounded, // chat comunidad
              itemIndex: 3,
            ),
          ],
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _navIcon({
    required IconData icon,
    required int itemIndex,
  }) {
    final bool isActive = itemIndex == currentIndex;
    final Color inactiveColor =
        isNightMode ? Colors.white70 : const Color(0xFF444444);
    final Color activeColor =
        isNightMode ? Colors.white : const Color(0xFF222222);

    return Icon(
      icon,
      size: isActive ? 30 : 26,
      color: isActive ? activeColor : inactiveColor,
    );
  }
}
