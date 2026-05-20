import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/ble_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/ble_provider.dart';

class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(connectionStateProvider).valueOrNull ?? false;
    final gpsData = ref.watch(gpsDataProvider).valueOrNull;
    final hasFix = gpsData?.fixValid ?? false;
    final sats = gpsData?.satellites ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StatusItem(
            icon: isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            color: isConnected ? AppTheme.accent : AppTheme.danger,
            label: isConnected ? 'Connected' : 'Disconnected',
          ),
          _StatusItem(
            icon: hasFix ? Icons.gps_fixed : Icons.gps_not_fixed,
            color: hasFix ? AppTheme.primary : AppTheme.textMuted,
            label: hasFix ? '$sats Sats' : 'No Fix',
          ),
        ],
      ),
    );
  }
}

class _StatusItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _StatusItem({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
      ],
    );
  }
}
