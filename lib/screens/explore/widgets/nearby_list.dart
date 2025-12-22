import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:latlong2/latlong.dart' show Distance, LengthUnit;

import '../explore_models.dart';

class NearbyList extends StatelessWidget {
  final bool night;
  final LatLng center;
  final List<NearbyUser> users;
  final bool isLoading;
  final String? errorText;
  final ValueChanged<NearbyUser> onSelect;

  const NearbyList({
    super.key,
    required this.night,
    required this.center,
    required this.users,
    required this.isLoading,
    required this.errorText,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: night ? Colors.white : const Color(0xFFFF5A5F),
        ),
      );
    }

    if (errorText != null) {
      return _buildMessage(
        text: errorText!,
        color: night ? Colors.redAccent : Colors.red,
        bold: true,
      );
    }

    if (users.isEmpty) {
      return _buildMessage(
        text: "No hay usuarios cercanos en este momento.",
        color: night ? Colors.white70 : Colors.black54,
      );
    }

    return _buildList();
  }

  Widget _buildList() {
    return Container(
      decoration: BoxDecoration(
        color: night
            ? Colors.black.withOpacity(0.85)
            : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: night
              ? Colors.white.withOpacity(0.15)
              : Colors.black.withOpacity(0.08),
        ),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(10),
        itemCount: users.length,
        separatorBuilder: (_, __) => Divider(
          color: night
              ? Colors.white.withOpacity(0.10)
              : Colors.black.withOpacity(0.06),
        ),
        itemBuilder: (context, i) {
          final u = users[i];

          final distanceKm = Distance().as(
            LengthUnit.Kilometer,
            center,
            LatLng(u.lat, u.lng),
          );

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFFF5A5F),
              child: u.avatarUrl == null
                  ? const Icon(Icons.person, color: Colors.white)
                  : ClipOval(
                      child: Image.network(
                        u.avatarUrl!,
                        fit: BoxFit.cover,
                        width: 40,
                        height: 40,
                      ),
                    ),
            ),
            title: Text(
              u.name,
              style: TextStyle(
                color: night ? Colors.white : Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              "A ${distanceKm.toStringAsFixed(2)} km",
              style: TextStyle(color: night ? Colors.white70 : Colors.black54),
            ),
            onTap: () => onSelect(u),
          );
        },
      ),
    );
  }

  Widget _buildMessage({
    required String text,
    required Color color,
    bool bold = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: night
            ? Colors.black.withOpacity(0.85)
            : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
