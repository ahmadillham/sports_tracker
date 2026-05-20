import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/ble_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/workout_provider.dart';
import '../../providers/ble_provider.dart';
import '../widgets/status_bar.dart';
import '../widgets/osm_live_map.dart';

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
    
    final pitch = sensorData?.pitch ?? 0.0;
    final leanAngle = (pitch.abs() > 90 ? 180 - pitch.abs() : pitch.abs()).toStringAsFixed(1);

    final speed = gpsData?.speed.toStringAsFixed(1) ?? '0.0';
    final distance = gpsData?.distance.toStringAsFixed(2) ?? '0.00';

    return Scaffold(
      appBar: AppBar(
        title: const Text('SPORT TRACKER'),
        actions: [
          if (activeWorkout.isActive)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  '${activeWorkout.mode.icon} ${activeWorkout.mode.label.toUpperCase()}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.primary),
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
                    pitch,
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'SELECT ACTIVITY',
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
            const SizedBox(height: 16),
            _ModeButton(
              mode: SportMode.pushup,
              onTap: () => _start(ref, SportMode.pushup),
            ),
            const SizedBox(height: 16),
            _ModeButton(
              mode: SportMode.squat,
              onTap: () => _start(ref, SportMode.squat),
            ),
            const SizedBox(height: 16),
            _ModeButton(
              mode: SportMode.plank,
              onTap: () => _start(ref, SportMode.plank),
            ),
          ],
        ),
      ),
    );
  }

  void _start(WidgetRef ref, SportMode mode) {
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
    double pitch,
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
        // ── Top Stats Grid ──
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Primary row (Time & HR usually)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _PrimaryStat(label: 'TIME', value: timeStr),
                  ),
                  Expanded(
                    child: _PrimaryStat(label: 'AVG HR', value: hr.toString(), unit: 'bpm', isHighlight: true),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Secondary row based on mode
              if (state.mode == SportMode.running || state.mode == SportMode.cycling)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PrimaryStat(label: 'DISTANCE', value: distance, unit: 'km'),
                    ),
                    Expanded(
                      child: _PrimaryStat(label: 'PACE', value: speed, unit: 'km/h'),
                    ),
                  ],
                ),
              if (state.mode == SportMode.jumpRope || state.mode == SportMode.pushup || state.mode == SportMode.squat)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PrimaryStat(label: 'REPS', value: jumps.toString(), unit: 'reps'),
                    ),
                    Expanded(
                      child: _PrimaryStat(label: 'CALORIES', value: state.caloriesBurned.toStringAsFixed(0), unit: 'kcal'),
                    ),
                  ],
                ),
              if (state.mode == SportMode.running || state.mode == SportMode.jumpRope)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: pitch.abs() > 20.0 ? AppTheme.danger.withValues(alpha: 0.1) : AppTheme.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: pitch.abs() > 20.0 ? AppTheme.danger : AppTheme.success, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        pitch.abs() > 20.0 
                            ? 'POSTUR: MEMBUNGKUK (${pitch.abs().toStringAsFixed(1)}°)' 
                            : 'POSTUR: IDEAL (${pitch.abs().toStringAsFixed(1)}°)',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: pitch.abs() > 20.0 ? AppTheme.danger : AppTheme.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              if (state.mode == SportMode.plank)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: jumps == 0 ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: jumps == 0 ? AppTheme.success : AppTheme.danger, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        jumps == 0 ? 'GOOD POSTURE' : 'WARNING: FIX FORM',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: jumps == 0 ? AppTheme.success : AppTheme.danger,
                        ),
                      ),
                    ),
                  ),
                ),
              if (state.mode == SportMode.cycling)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _PrimaryStat(label: 'LEAN ANGLE', value: leanAngle, unit: '°'),
                      ),
                      Expanded(
                        child: _PrimaryStat(label: 'CALORIES', value: state.caloriesBurned.toStringAsFixed(0), unit: 'kcal'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // ── Map (Only for GPS modes) ──
        if (state.mode == SportMode.running || state.mode == SportMode.cycling)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: OsmLiveMap(
                routePoints: state.routePoints,
                currentLat: lat,
                currentLng: lng,
                hasFix: gpsFix,
              ),
            ),
          )
        else
           const Spacer(),

        // ── Bottom Action ──
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              ),
              onPressed: () {
                ref.read(bleServiceProvider).sendCommand(SportMode.idle, 180);
                ref.read(activeWorkoutProvider.notifier).stopWorkoutAndSave();
              },
              child: Text(
                'FINISH WORKOUT',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  letterSpacing: 2.0,
                ),
              ),
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.surfaceLight),
        ),
        child: Row(
          children: [
            Text(mode.icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 24),
            Text(
              mode.label.toUpperCase(),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryStat extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final bool isHighlight;

  const _PrimaryStat({
    required this.label, 
    required this.value, 
    this.unit,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: isHighlight ? AppTheme.primary : AppTheme.textSecondary,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: isHighlight ? AppTheme.primary : AppTheme.textPrimary,
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 8),
              Text(
                unit!,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ]
          ],
        ),
      ],
    );
  }
}
