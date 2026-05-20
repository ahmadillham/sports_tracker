import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_theme.dart';

class LiveMapWidget extends StatelessWidget {
  final List<List<double>> routePoints;
  final double currentLat;
  final double currentLng;
  final bool hasFix;

  const LiveMapWidget({
    super.key,
    required this.routePoints,
    required this.currentLat,
    required this.currentLng,
    required this.hasFix,
  });

  @override
  Widget build(BuildContext context) {
    final points = routePoints.map((p) => LatLng(p[0], p[1])).toList();
    final center = hasFix && currentLat != 0.0
        ? LatLng(currentLat, currentLng)
        : (points.isNotEmpty ? points.last : const LatLng(0, 0));

    return Container(
      decoration: AppTheme.glassCard(),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 16.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sporttracker.app',
                // Darken the map for dark theme
                tileBuilder: (context, tileWidget, tile) {
                  return ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      -1, 0, 0, 0, 255, //
                      0, -1, 0, 0, 255, //
                      0, 0, -1, 0, 255, //
                      0, 0, 0, 1, 0, //
                    ]),
                    child: tileWidget,
                  );
                },
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points,
                    color: AppTheme.primary,
                    strokeWidth: 4.0,
                  ),
                ],
              ),
              if (hasFix && currentLat != 0.0)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(currentLat, currentLng),
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accent.withValues(alpha: 0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (!hasFix)
            Container(
              color: AppTheme.background.withValues(alpha: 0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gps_off, color: AppTheme.textMuted, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      'Waiting for GPS Lock...',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
