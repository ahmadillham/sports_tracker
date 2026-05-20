import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/ble_constants.dart';

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color iconColor;
  final bool animatePulse;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    this.iconColor = AppTheme.accent,
    this.animatePulse = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassCard(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildIcon(),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Text(
                  unit,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    if (!animatePulse) {
      return Icon(icon, color: iconColor, size: 20);
    }
    return HeartPulseIcon(icon: icon, color: iconColor);
  }
}

class HeartPulseIcon extends StatefulWidget {
  final IconData icon;
  final Color color;

  const HeartPulseIcon({super.key, required this.icon, required this.color});

  @override
  State<HeartPulseIcon> createState() => _HeartPulseIconState();
}

class _HeartPulseIconState extends State<HeartPulseIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Icon(widget.icon, color: widget.color, size: 20),
    );
  }
}
