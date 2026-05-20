import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/workout_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workouts = ref.watch(workoutHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout History'),
      ),
      body: workouts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history, size: 64, color: AppTheme.textMuted),
                  const SizedBox(height: 16),
                  Text(
                    'No workouts yet.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: workouts.length,
              itemBuilder: (context, index) {
                final session = workouts[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Container(
                    decoration: AppTheme.glassCard(),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.surfaceLight,
                        child: Text(session.mode.icon, style: const TextStyle(fontSize: 24)),
                      ),
                      title: Text(
                        session.mode.label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        DateFormat('MMM d, yyyy • h:mm a').format(session.startTime),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            session.formattedDuration,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          Text(
                            '${session.calories.toStringAsFixed(0)} kcal',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        // TODO: Navigate to History Detail Screen
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
