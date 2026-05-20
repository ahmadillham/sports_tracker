import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/utils/calorie_calculator.dart';
import '../core/constants/ble_constants.dart';
import '../data/models/models.dart';
import '../data/repositories/workout_repository.dart';
import 'ble_provider.dart';

// Provides the WorkoutRepository instance (needs to be initialized in main)
final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  throw UnimplementedError('Initialize in main.dart');
});

// Provides the history list, automatically reloading when a workout is saved
final workoutHistoryProvider = StateNotifierProvider<WorkoutHistoryNotifier, List<WorkoutSession>>((ref) {
  final repo = ref.watch(workoutRepositoryProvider);
  return WorkoutHistoryNotifier(repo);
});

class WorkoutHistoryNotifier extends StateNotifier<List<WorkoutSession>> {
  final WorkoutRepository _repo;

  WorkoutHistoryNotifier(this._repo) : super([]) {
    loadWorkouts();
  }

  void loadWorkouts() {
    state = _repo.getAllWorkouts();
  }

  Future<void> deleteWorkout(String id) async {
    await _repo.deleteWorkout(id);
    loadWorkouts();
  }
}

// ── Active Workout State ──
class ActiveWorkoutState {
  final bool isActive;
  final SportMode mode;
  final int durationSeconds;
  final double caloriesBurned;
  final List<List<double>> routePoints;
  final List<int> _hrHistory; // Internal for avg calculation

  const ActiveWorkoutState({
    this.isActive = false,
    this.mode = SportMode.idle,
    this.durationSeconds = 0,
    this.caloriesBurned = 0.0,
    this.routePoints = const [],
    List<int> hrHistory = const [],
  }) : _hrHistory = hrHistory;

  ActiveWorkoutState copyWith({
    bool? isActive,
    SportMode? mode,
    int? durationSeconds,
    double? caloriesBurned,
    List<List<double>>? routePoints,
    List<int>? hrHistory,
  }) {
    return ActiveWorkoutState(
      isActive: isActive ?? this.isActive,
      mode: mode ?? this.mode,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      routePoints: routePoints ?? this.routePoints,
      hrHistory: hrHistory ?? _hrHistory,
    );
  }
}

// Manages the active workout session (timer, calories, route accumulation)
final activeWorkoutProvider = StateNotifierProvider<ActiveWorkoutNotifier, ActiveWorkoutState>((ref) {
  return ActiveWorkoutNotifier(ref);
});

class ActiveWorkoutNotifier extends StateNotifier<ActiveWorkoutState> {
  final Ref _ref;
  Timer? _timer;

  ActiveWorkoutNotifier(this._ref) : super(const ActiveWorkoutState());

  void startWorkout(SportMode mode) {
    state = ActiveWorkoutState(isActive: true, mode: mode);
    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  void _onTick(Timer timer) {
    if (!state.isActive) return;

    // Get latest sensor data for calorie calc
    final sensorData = _ref.read(sensorDataProvider).valueOrNull ?? const SensorData();
    final hr = sensorData.heartRate;

    // Accumulate route points if we have a valid GPS fix
    final gpsData = _ref.read(gpsDataProvider).valueOrNull;
    List<List<double>> newRoute = List.from(state.routePoints);
    if (gpsData != null && gpsData.fixValid && gpsData.latitude != 0.0) {
      // Only add point if it's sufficiently different from the last one to save memory
      if (newRoute.isEmpty ||
          _distanceSquared(newRoute.last[0], newRoute.last[1], gpsData.latitude, gpsData.longitude) > 0.0000001) {
        newRoute.add([gpsData.latitude, gpsData.longitude]);
      }
    }

    // Accumulate HR history
    List<int> newHrHistory = List.from(state._hrHistory);
    if (hr > 0) newHrHistory.add(hr);

    // Calculate incremental calories (1 second worth)
    final incrementalCals = CalorieCalculator.caloriesPerMinute(hr) / 60.0;

    state = state.copyWith(
      durationSeconds: state.durationSeconds + 1,
      caloriesBurned: state.caloriesBurned + incrementalCals,
      routePoints: newRoute,
      hrHistory: newHrHistory,
    );
  }

  double _distanceSquared(double lat1, double lon1, double lat2, double lon2) {
    return (lat1 - lat2) * (lat1 - lat2) + (lon1 - lon2) * (lon1 - lon2);
  }

  Future<void> stopWorkoutAndSave() async {
    if (!state.isActive || state.durationSeconds < 10) {
      // Too short to save
      reset();
      return;
    }

    _timer?.cancel();

    // Gather final stats
    final sensorData = _ref.read(sensorDataProvider).valueOrNull ?? const SensorData();
    final gpsData = _ref.read(gpsDataProvider).valueOrNull ?? const GpsData();

    int avgHr = 0;
    int maxHr = 0;
    if (state._hrHistory.isNotEmpty) {
      avgHr = (state._hrHistory.reduce((a, b) => a + b) / state._hrHistory.length).round();
      maxHr = state._hrHistory.reduce((a, b) => a > b ? a : b);
    }

    final session = WorkoutSession(
      id: const Uuid().v4(),
      mode: state.mode,
      startTime: DateTime.now().subtract(Duration(seconds: state.durationSeconds)),
      durationSeconds: state.durationSeconds,
      calories: state.caloriesBurned,
      distance: gpsData.distance, // From ESP32 cumulative distance
      steps: sensorData.stepCount,
      jumps: sensorData.jumpCount,
      avgHeartRate: avgHr,
      maxHeartRate: maxHr,
      routePoints: state.routePoints,
    );

    // Save to Hive
    await _ref.read(workoutRepositoryProvider).saveWorkout(session);

    // Refresh history
    _ref.read(workoutHistoryProvider.notifier).loadWorkouts();

    reset();
  }

  void reset() {
    _timer?.cancel();
    state = const ActiveWorkoutState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
