import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/ble_provider.dart';
import 'dashboard_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isScanning = false;
  String _status = 'Ready to Connect';

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  Future<void> _scanAndConnect() async {
    await _requestPermissions();

    setState(() {
      _isScanning = true;
      _status = 'Searching for SportTracker...';
    });

    final bleService = ref.read(bleServiceProvider);
    
    // Disconnect if already connected
    if (bleService.isConnected) {
      await bleService.disconnect();
    }

    final device = await bleService.scan();

    if (device == null) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _status = 'Device not found. Make sure it is powered on.';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _status = 'Found device! Connecting...';
      });
    }

    final success = await bleService.connect(device);

    if (mounted) {
      setState(() {
        _isScanning = false;
        if (success) {
          _status = 'Connected!';
          _navigateToDashboard();
        } else {
          _status = 'Connection failed. Please try again.';
        }
      });
    }
  }

  void _navigateToDashboard() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.background,
              AppTheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo / Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.directions_run,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 48),
                Text(
                  'SportTracker',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(height: 64),
                if (_isScanning)
                  const CircularProgressIndicator(color: AppTheme.primary)
                else
                  ElevatedButton.icon(
                    onPressed: _scanAndConnect,
                    icon: const Icon(Icons.bluetooth),
                    label: const Text('CONNECT DEVICE'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
