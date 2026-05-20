import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/ble_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/workout_provider.dart';
import '../../providers/ble_provider.dart';
import '../widgets/status_bar.dart';
import '../widgets/metric_card.dart';
import '../widgets/live_map_widget.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeWorkout = ref.watch(activeWorkoutProvider);
    final sensorData = ref.watch(sensorDataProvider).valueOrNull;
    final gpsData = ref.watch(gpsDataProvider).valueOrNull;

    final hr = sensorData?.heartRate ?? 0;
    final steps = sensorData?.stepCount ?? 0;
    final jumps = sensorData?.jumpCount ?? 0;
    
    // Convert pitch to absolute lean angle (0 = upright)
    final pitch = sensorData?.pitch ?? 0.0;
    final leanAngle = (pitch.abs() > 90 ? 180 - pitch.abs() : pitch.abs()).toStringAsFixed(1);

    final speed = gpsData?.speed.toStringAsFixed(1) ?? '0.0';
    final distance = gpsData?.distance.toStringAsFixed(2) ?? '0.00';

    return Scaffold(
      appBar: AppBar(
        title: const Text('SportTracker'),
        actions: [
          if (activeWorkout.isActive)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  '${activeWorkout.mode.icon} ${activeWorkout.mode.label}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          const StatusBar(),
          Expanded(
            child: activeWorkout.isActive
                ? _buildActiveWorkout(
                    context,
                    ref,
                    activeWorkout,
                    hr,
                    steps,
                    jumps,
                    speed,
                    distance,
                    leanAngle,
                    gpsData?.fixValid ?? false,
                    gpsData?.latitude ?? 0.0,
                    gpsData?.longitude ?? 0.0,
                  )
                : _buildModeSelector(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Select Activity',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 32),
            _ModeButton(
              mode: SportMode.running,
              onTap: () => _start(ref, SportMode.running),
            ),
            const SizedBox(height: 16),
            _ModeButton(
              mode: SportMode.cycling,
              onTap: () => _start(ref, SportMode.cycling),
            ),
            const SizedBox(height: 16),
            _ModeButton(
              mode: SportMode.jumpRope,
              onTap: () => _start(ref, SportMode.jumpRope),
            ),
          ],
        ),
      ),
    );
  }

  void _start(WidgetRef ref, SportMode mode) {
    // Send command to ESP32: mode and Max HR (hardcoded to 180 for now)
    ref.read(bleServiceProvider).sendCommand(mode, 180);
    ref.read(activeWorkoutProvider.notifier).startWorkout(mode);
  }

  Widget _buildActiveWorkout(
    BuildContext context,
    WidgetRef ref,
    ActiveWorkoutState state,
    int hr,
    int steps,
    int jumps,
    String speed,
    String distance,
    String leanAngle,
    bool gpsFix,
    double lat,
    double lng,
  ) {
    final h = state.durationSeconds ~/ 3600;
    final m = (state.durationSeconds % 3600) ~/ 60;
    final s = state.durationSeconds % 60;
    final timeStr = '${h > 0 ? '$h:' : ''}${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    return Column(
      children: [
        // ── Top Summary ──
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _SummaryStat(label: 'TIME', value: timeStr),
              _SummaryStat(
                label: 'CALORIES',
                value: state.caloriesBurned.toStringAsFixed(0),
                unit: 'kcal',
              ),
            ],
          ),
        ),

        // ── Metrics Grid ──
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                MetricCard(
                  title: 'HEART RATE',
                  value: hr.toString(),
                  unit: 'bpm',
                  icon: Icons.favorite,
                  iconColor: AppTheme.heartRed,
                  animatePulse: hr > 0,
                ),
                if (state.mode == SportMode.running)
                  MetricCard(
                    title: 'STEPS',
                    value: steps.toString(),
                    unit: 'steps',
                    icon: Icons.directions_run,
                  ),
                if (state.mode == SportMode.jumpRope)
                  MetricCard(
                    title: 'JUMPS',
                    value: jumps.toString(),
                    unit: 'reps',
                    icon: Icons.sports_gymnastics,
                  ),
                if (state.mode == SportMode.running || state.mode == SportMode.cycling) ...[
                  MetricCard(
                    title: 'SPEED',
                    value: speed,
                    unit: 'km/h',
                    icon: Icons.speed,
                  ),
                  MetricCard(
                    title: 'DISTANCE',
                    value: distance,
                    unit: 'km',
                    icon: Icons.route,
                  ),
                ],
                if (state.mode == SportMode.cycling)
                  MetricCard(
                    title: 'LEAN',
                    value: leanAngle,
                    unit: '°',
                    icon: Icons.screen_rotation,
                  ),
              ],
            ),
          ),
        ),

        // ── Map (Only for GPS modes) ──
        if (state.mode != SportMode.jumpRope)
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: LiveMapWidget(
                routePoints: state.routePoints,
                currentLat: lat,
                currentLng: lng,
                hasFix: gpsFix,
              ),
            ),
          ),

        // ── Controls ──
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                // Send idle command to ESP32
                ref.read(bleServiceProvider).sendCommand(SportMode.idle, 180);
                ref.read(activeWorkoutProvider.notifier).stopWorkoutAndSave();
              },
              child: const Text('STOP WORKOUT'),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  final SportMode mode;
  final VoidCallback onTap;

  const _ModeButton({required this.mode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.glassCard(),
        child: Row(
          children: [
            Text(mode.icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Text(
              mode.label,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: AppTheme.primary),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;

  const _SummaryStat({required this.label, required this.value, this.unit});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 40),
            ),
            if (unit != null) ...[
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  unit!,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.primary,
                      ),
                ),
              ),
            ]
          ],
        ),
      ],
    );
  }
}
