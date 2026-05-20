import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/workout_repository.dart';
import 'providers/workout_provider.dart';
import 'ui/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  
  // Initialize Repository
  final workoutRepo = WorkoutRepository();
  await workoutRepo.init();

  runApp(
    ProviderScope(
      overrides: [
        workoutRepositoryProvider.overrideWithValue(workoutRepo),
      ],
      child: const SportApp(),
    ),
  );
}

class SportApp extends StatelessWidget {
  const SportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SportTracker',
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
