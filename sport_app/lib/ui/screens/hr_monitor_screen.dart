import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/ble_provider.dart';
import '../../providers/workout_provider.dart';
import '../widgets/hr_ring_widget.dart';
import '../widgets/hr_zone_bar.dart';

class HrMonitorScreen extends ConsumerWidget {
  const HrMonitorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sensorData = ref.watch(sensorDataProvider).valueOrNull;
    final profile = ref.watch(userProfileProvider);
    final isConnected = ref.watch(bleServiceProvider).isConnected;

    final hr = sensorData?.heartRate ?? 0;
    final maxHR = profile.maxHR;

    return Scaffold(
      appBar: AppBar(
        title: const Text('HEART RATE MONITOR'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Connection Status Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isConnected 
                      ? AppTheme.success.withValues(alpha: 0.15) 
                      : AppTheme.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isConnected ? AppTheme.success : AppTheme.danger,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      color: isConnected ? AppTheme.success : AppTheme.danger,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isConnected ? 'SENSOR CONNECTED' : 'DISCONNECTED',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: isConnected ? AppTheme.success : AppTheme.danger,
                          ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 64),
              
              // Big HR Ring
              Center(
                child: HrRingWidget(
                  heartRate: hr,
                  maxHR: maxHR,
                  size: 240, // Larger size for the dedicated screen
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Zone Bar
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.surfaceLight),
                ),
                child: Column(
                  children: [
                    Text(
                      'CURRENT ZONE',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppTheme.textMuted,
                            letterSpacing: 1.5,
                          ),
                    ),
                    const SizedBox(height: 16),
                    HrZoneBar(heartRate: hr, maxHR: maxHR),
                  ],
                ),
              ),
              
              const Spacer(),
              
              if (!isConnected)
                Text(
                  'Please connect your device to view real-time heart rate.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
