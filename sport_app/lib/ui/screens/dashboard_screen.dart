import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/ble_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/workout_provider.dart';
import '../../providers/ble_provider.dart';
import '../widgets/status_bar.dart';
import '../widgets/osm_live_map.dart';

/// A Riverpod provider to track the currently *selected* mode before starting.
final selectedModeProvider = StateProvider<SportMode>((ref) => SportMode.running);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeWorkout = ref.watch(activeWorkoutProvider);
    final selectedMode = ref.watch(selectedModeProvider);
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(activeWorkout.mode.icon, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      activeWorkout.mode.label.toUpperCase(),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.primary),
                    ),
                  ],
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
                    context, ref, activeWorkout,
                    hr, steps, jumps, speed, distance, pitch, leanAngle,
                    gpsData?.fixValid ?? false,
                    gpsData?.latitude ?? 0.0,
                    gpsData?.longitude ?? 0.0,
                  )
                : _buildIdleDashboard(context, ref, selectedMode, gpsData),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  IDLE STATE — Preview + Activity Picker + START
  // ═══════════════════════════════════════════════
  Widget _buildIdleDashboard(BuildContext context, WidgetRef ref, SportMode selectedMode, dynamic gpsData) {
    final gpsFix = gpsData?.fixValid ?? false;
    final lat = gpsData?.latitude ?? 0.0;
    final lng = gpsData?.longitude ?? 0.0;

    return Column(
      children: [
        // ── Preview area based on selected mode ──
        Expanded(
          child: selectedMode.isOutdoor
              ? _buildMapPreview(gpsFix, lat, lng)
              : _buildIndoorPreview(context, selectedMode),
        ),

        // ── Activity Selector Chip ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: InkWell(
            onTap: () => _showModePicker(context, ref),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.surfaceLight),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(selectedMode.icon, color: AppTheme.primary, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    selectedMode.label.toUpperCase(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.keyboard_arrow_down, color: AppTheme.textSecondary),
                ],
              ),
            ),
          ),
        ),

        // ── START button ──
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              ),
              onPressed: () {
                final mode = ref.read(selectedModeProvider);
                ref.read(bleServiceProvider).sendCommand(mode, 180);
                ref.read(activeWorkoutProvider.notifier).startWorkout(mode);
              },
              child: Text(
                'START',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  letterSpacing: 4.0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapPreview(bool gpsFix, double lat, double lng) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: OsmLiveMap(
        routePoints: const [],
        currentLat: lat,
        currentLng: lng,
        hasFix: gpsFix,
      ),
    );
  }

  Widget _buildIndoorPreview(BuildContext context, SportMode mode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            mode.icon,
            size: 100,
            color: AppTheme.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          Text(
            mode.label.toUpperCase(),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppTheme.textMuted,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'TAP START TO BEGIN',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  BOTTOM SHEET — Mode Picker
  // ═══════════════════════════════════════════════
  void _showModePicker(BuildContext context, WidgetRef ref) {
    final currentMode = ref.read(selectedModeProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'SELECT ACTIVITY',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.textSecondary,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 20),

              // ── Outdoor Section ──
              _SectionLabel(label: 'OUTDOOR'),
              const SizedBox(height: 8),
              _ModeSheetItem(
                mode: SportMode.running,
                isSelected: currentMode == SportMode.running,
                onTap: () => _selectMode(ref, ctx, SportMode.running),
              ),
              const SizedBox(height: 8),
              _ModeSheetItem(
                mode: SportMode.cycling,
                isSelected: currentMode == SportMode.cycling,
                onTap: () => _selectMode(ref, ctx, SportMode.cycling),
              ),

              const SizedBox(height: 20),

              // ── Indoor Section ──
              _SectionLabel(label: 'INDOOR'),
              const SizedBox(height: 8),
              _ModeSheetItem(
                mode: SportMode.jumpRope,
                isSelected: currentMode == SportMode.jumpRope,
                onTap: () => _selectMode(ref, ctx, SportMode.jumpRope),
              ),
              const SizedBox(height: 8),
              _ModeSheetItem(
                mode: SportMode.pushup,
                isSelected: currentMode == SportMode.pushup,
                onTap: () => _selectMode(ref, ctx, SportMode.pushup),
              ),
              const SizedBox(height: 8),
              _ModeSheetItem(
                mode: SportMode.squat,
                isSelected: currentMode == SportMode.squat,
                onTap: () => _selectMode(ref, ctx, SportMode.squat),
              ),
              const SizedBox(height: 8),
              _ModeSheetItem(
                mode: SportMode.plank,
                isSelected: currentMode == SportMode.plank,
                onTap: () => _selectMode(ref, ctx, SportMode.plank),
              ),
            ],
          ),
        );
      },
    );
  }

  void _selectMode(WidgetRef ref, BuildContext ctx, SportMode mode) {
    ref.read(selectedModeProvider.notifier).state = mode;
    Navigator.pop(ctx);
  }

  // ═══════════════════════════════════════════════
  //  ACTIVE WORKOUT — Live Stats
  // ═══════════════════════════════════════════════
  Widget _buildActiveWorkout(
    BuildContext context,
    WidgetRef ref,
    ActiveWorkoutState state,
    int hr, int steps, int jumps,
    String speed, String distance,
    double pitch, String leanAngle,
    bool gpsFix, double lat, double lng,
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
                    Expanded(child: _PrimaryStat(label: 'DISTANCE', value: distance, unit: 'km')),
                    Expanded(child: _PrimaryStat(label: 'PACE', value: speed, unit: 'km/h')),
                  ],
                ),
              if (state.mode == SportMode.jumpRope || state.mode == SportMode.pushup || state.mode == SportMode.squat)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _PrimaryStat(label: 'REPS', value: jumps.toString(), unit: 'reps')),
                    Expanded(child: _PrimaryStat(label: 'CALORIES', value: state.caloriesBurned.toStringAsFixed(0), unit: 'kcal')),
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
                      Expanded(child: _PrimaryStat(label: 'LEAN ANGLE', value: leanAngle, unit: '°')),
                      Expanded(child: _PrimaryStat(label: 'CALORIES', value: state.caloriesBurned.toStringAsFixed(0), unit: 'kcal')),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // ── Map (Only for GPS modes) ──
        if (state.mode.isOutdoor)
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

        // ── FINISH Button ──
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              ),
              onPressed: () {
                ref.read(bleServiceProvider).sendCommand(SportMode.idle, 180);
                ref.read(activeWorkoutProvider.notifier).stopWorkoutAndSave();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.stop_circle_outlined, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'FINISH',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════
//  PRIVATE WIDGETS
// ═══════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 2.0,
        ),
      ),
    );
  }
}

class _ModeSheetItem extends StatelessWidget {
  final SportMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeSheetItem({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.12) : AppTheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.surfaceLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              mode.icon,
              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                mode.label.toUpperCase(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppTheme.primary, size: 24),
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
