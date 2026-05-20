import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/ble_constants.dart';
import '../../data/models/models.dart';

class HistoryDetailScreen extends StatefulWidget {
  final WorkoutSession session;

  const HistoryDetailScreen({super.key, required this.session});

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final List<LatLng> polylinePoints = widget.session.routePoints
        .map((p) => LatLng(p[0], p[1]))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.session.mode.label.toUpperCase()} ACTIVITY'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── User Header ──
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.surfaceLight,
                    child: Icon(Icons.person, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Morning ${widget.session.mode.label}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        DateFormat('EEEE, MMM d, yyyy @ h:mm a').format(widget.session.startTime),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Primary Summary Stats ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  if (widget.session.mode == SportMode.running || widget.session.mode == SportMode.cycling) ...[
                    Expanded(
                      child: _DetailStat(
                        label: 'Distance',
                        value: '${widget.session.distance.toStringAsFixed(2)} km',
                      ),
                    ),
                    Expanded(
                      child: _DetailStat(
                        label: 'Avg Pace',
                        value: widget.session.distance > 0 
                            ? '${(widget.session.durationSeconds / 60 / widget.session.distance).toStringAsFixed(2)} /km'
                            : '--',
                      ),
                    ),
                  ] else if (widget.session.mode == SportMode.plank) ...[
                     Expanded(
                      child: _DetailStat(
                        label: 'Posture',
                        value: widget.session.jumps == 0 ? 'Good' : 'Warning',
                      ),
                    ),
                  ] else ...[
                     Expanded(
                      child: _DetailStat(
                        label: 'Total Reps',
                        value: '${widget.session.jumps}',
                      ),
                    ),
                  ],
                  Expanded(
                    child: _DetailStat(
                      label: 'Time',
                      value: widget.session.formattedDuration,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Static Map Route (Only GPS modes) ──
            if (widget.session.mode == SportMode.running || widget.session.mode == SportMode.cycling)
              if (widget.session.routePoints.isNotEmpty)
              SizedBox(
                height: 300,
                width: double.infinity,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCameraFit: CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(polylinePoints),
                      padding: const EdgeInsets.all(50.0),
                    ),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none, // Static map
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.sporttracker.app',
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
                          points: polylinePoints,
                          color: AppTheme.primary,
                          strokeWidth: 5.0,
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Container(
                height: 200,
                color: AppTheme.surface,
                child: const Center(
                  child: Text('No GPS data recorded for this activity.'),
                ),
              ),

            // ── Detailed Stats Grid ──
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.surfaceLight),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _DetailStat(label: 'Calories', value: '${widget.session.calories.toStringAsFixed(0)} kcal')),
                        Expanded(child: _DetailStat(label: 'Avg Heart Rate', value: '${widget.session.avgHeartRate} bpm')),
                      ],
                    ),
                    const Divider(height: 32, color: AppTheme.surfaceLight),
                    Row(
                      children: [
                        Expanded(child: _DetailStat(label: 'Max Heart Rate', value: '${widget.session.maxHeartRate} bpm')),
                        if (widget.session.mode == SportMode.running)
                          Expanded(child: _DetailStat(label: 'Steps', value: '${widget.session.steps}')),
                        if (widget.session.mode == SportMode.jumpRope || widget.session.mode == SportMode.pushup || widget.session.mode == SportMode.squat)
                          Expanded(child: _DetailStat(label: 'Reps', value: '${widget.session.jumps}')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final String label;
  final String value;

  const _DetailStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}
