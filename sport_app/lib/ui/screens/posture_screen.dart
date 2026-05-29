import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/ble_provider.dart';
import '../widgets/glassmorphic_card.dart';

class PostureScreen extends ConsumerStatefulWidget {
  const PostureScreen({super.key});

  @override
  ConsumerState<PostureScreen> createState() => _PostureScreenState();
}

class _PostureScreenState extends ConsumerState<PostureScreen> with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final sensorData = ref.watch(sensorDataProvider).valueOrNull;
    final isConnected = ref.watch(bleServiceProvider).isConnected;

    final pitch = sensorData?.pitch ?? 0.0;
    final roll = sensorData?.roll ?? 0.0;
    
    // Calculate if posture is good (within 15 degrees)
    final isPitchGood = pitch.abs() <= 15.0;
    final isRollGood = roll.abs() <= 15.0;
    final isPostureGood = isPitchGood && isRollGood;

    return Scaffold(
      appBar: AppBar(
        title: const Text('POSTURE CORRECTION'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Connection Status
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
              
              const SizedBox(height: 32),
              
              // Posture Visualizer
              Expanded(
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Target area (safe zone)
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.success.withValues(alpha: 0.1),
                          border: Border.all(
                            color: AppTheme.success.withValues(alpha: 0.3),
                            width: 2,
                            style: BorderStyle.solid,
                          ),
                        ),
                      ),
                      
                      // Outer boundary ring
                      Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.surfaceLight,
                            width: 1,
                          ),
                        ),
                      ),
                      
                      // Axes
                      Container(width: 280, height: 1, color: AppTheme.surfaceLight.withValues(alpha: 0.5)),
                      Container(width: 1, height: 280, color: AppTheme.surfaceLight.withValues(alpha: 0.5)),
                      
                      // The marker (representing the device's tilt)
                      // Pitch maps to Y axis (up/down), Roll maps to X axis (left/right)
                      // Limit max visualization angle to 90 degrees
                      if (isConnected)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 100),
                          curve: Curves.easeOut,
                          top: 140 - 12 - (pitch.clamp(-90.0, 90.0) / 90.0 * 140),
                          left: 140 - 12 + (roll.clamp(-90.0, 90.0) / 90.0 * 140),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isPostureGood ? AppTheme.success : AppTheme.danger,
                              boxShadow: [
                                BoxShadow(
                                  color: (isPostureGood ? AppTheme.success : AppTheme.danger).withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Status text
              Text(
                isPostureGood ? 'GOOD POSTURE' : 'ADJUST YOUR POSTURE',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: isPostureGood ? AppTheme.success : AppTheme.danger,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Keep the dot inside the green circle (±15°)',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
              
              const SizedBox(height: 32),
              
              // Angle Cards
              Row(
                children: [
                  Expanded(
                    child: GlassmorphicCard(
                      label: 'PITCH (FRONT/BACK)',
                      value: '${pitch.toStringAsFixed(1)}°',
                      icon: Icons.height,
                      accentColor: isPitchGood ? AppTheme.success : AppTheme.danger,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GlassmorphicCard(
                      label: 'ROLL (LEFT/RIGHT)',
                      value: '${roll.toStringAsFixed(1)}°',
                      icon: Icons.swap_horiz,
                      accentColor: isRollGood ? AppTheme.success : AppTheme.danger,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
