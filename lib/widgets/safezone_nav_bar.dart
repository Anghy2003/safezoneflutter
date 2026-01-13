import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';

class SafeZoneNavBar extends StatelessWidget {
  final int currentIndex;
  final bool isNightMode;

  /// Para levantar la barra si lo necesitas
  final double bottomExtra;

  final ValueChanged<int> onTap;

  /// Avatar del usuario (url)
  final String? photoUrl;

  const SafeZoneNavBar({
    super.key,
    required this.currentIndex,
    required this.isNightMode,
    required this.onTap,
    this.photoUrl,
    this.bottomExtra = 0,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final sysBottom = media.viewPadding.bottom;

    final barColor = isNightMode ? const Color(0xFF181A24) : Colors.white;

    // ✅ 4 items fijos: Home, Explorar, Comunidades, Menú
    const itemsCount = 4;
    final safeIndex = currentIndex.clamp(0, itemsCount - 1);

    final compact = w < 380;

    final navHeight = compact ? 56.0 : 64.0;
    final iconSizeActive = compact ? 24.0 : 30.0;
    final iconSizeInactive = compact ? 21.0 : 26.0;

    final sidePadding = compact ? 8.0 : 14.0;
    final bottomPad = (compact ? 10 : 12) + bottomExtra + sysBottom;

    final items = <Widget>[
      _navIcon(
        icon: Icons.home_rounded,
        itemIndex: 0,
        selectedIndex: safeIndex,
        active: iconSizeActive,
        inactive: iconSizeInactive,
      ),
      _navIcon(
        icon: Icons.explore_rounded,
        itemIndex: 1,
        selectedIndex: safeIndex,
        active: iconSizeActive,
        inactive: iconSizeInactive,
      ),
      _navIcon(
        icon: Icons.groups_rounded,
        itemIndex: 2,
        selectedIndex: safeIndex,
        active: iconSizeActive,
        inactive: iconSizeInactive,
      ),
      _avatarMenuItem(
        itemIndex: 3,
        selectedIndex: safeIndex,
        size: compact ? 30 : 34,
        photoUrl: photoUrl,
      ),
    ];

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(left: sidePadding, right: sidePadding, bottom: bottomPad),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isNightMode ? 0.55 : 0.10),
                  blurRadius: isNightMode ? 18 : 24,
                  offset: Offset(0, isNightMode ? 8 : 10),
                ),
              ],
            ),
            child: CurvedNavigationBar(
              index: safeIndex,
              height: navHeight,
              backgroundColor: Colors.transparent,
              color: barColor,
              buttonBackgroundColor: const Color(0xFFFF5A5F),
              animationCurve: Curves.easeOutCubic,
              animationDuration: const Duration(milliseconds: 280),
              items: items,
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
  }

  Widget _navIcon({
    required IconData icon,
    required int itemIndex,
    required int selectedIndex,
    required double active,
    required double inactive,
  }) {
    final isActive = itemIndex == selectedIndex;

    final inactiveColor = isNightMode ? Colors.white70 : const Color(0xFF444444);
    final activeColor = isNightMode ? Colors.white : const Color(0xFF222222);

    return Icon(
      icon,
      size: isActive ? active : inactive,
      color: isActive ? activeColor : inactiveColor,
    );
  }

  Widget _avatarMenuItem({
    required int itemIndex,
    required int selectedIndex,
    required double size,
    required String? photoUrl,
  }) {
    final isActive = itemIndex == selectedIndex;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? Colors.white : const Color(0xFFFF5A5F),
              width: 2,
            ),
            color: Colors.white,
          ),
          child: ClipOval(
            child: (photoUrl != null && photoUrl.trim().isNotEmpty)
                ? Image.network(photoUrl, fit: BoxFit.cover)
                : const Icon(Icons.person, size: 18, color: Color(0xFFFF5A5F)),
          ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5A5F),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: const Icon(Icons.menu_rounded, size: 12, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
