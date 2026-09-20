// lib/screens/anti_theft_setup_screen.dart
//
// Pro-gated setup screen for anti-theft mode. Lets users toggle the feature,
// pick a sensitivity level, and test the alarm. The feature is Pro-only —
// free users are routed to the paywall via ProGate.

import 'package:flutter/material.dart';
import 'package:geowake2/services/anti_theft_service.dart';
import 'package:geowake2/services/monetization/monetization_service.dart';
import 'package:geowake2/services/monetization/premium_service.dart';
import 'package:geowake2/widgets/monetization/pro_gate.dart';

class AntiTheftSetupScreen extends StatefulWidget {
  const AntiTheftSetupScreen({super.key});

  @override
  State<AntiTheftSetupScreen> createState() => _AntiTheftSetupScreenState();
}

class _AntiTheftSetupScreenState extends State<AntiTheftSetupScreen> {
  final _service = AntiTheftService.instance;
  bool _enabled = false;
  AntiTheftSensitivity _sensitivity = AntiTheftSensitivity.medium;
  bool _chargerDetection = true;
  bool _loading = true;

  bool get _allowed =>
      MonetizationService.instance.premiumOrNull?.canUseAntiTheft ?? false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _service.load();
    if (!mounted) return;
    setState(() {
      _enabled = _service.isEnabled;
      _sensitivity = _service.sensitivity;
      _chargerDetection = _service.chargerDetectionEnabled;
      _loading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    try {
      await _service.setEnabled(value);
      if (mounted) setState(() => _enabled = value);
    } on AntiTheftDenied {
      _toPaywall();
    }
  }

  Future<void> _setSensitivity(AntiTheftSensitivity s) async {
    try {
      await _service.setSensitivity(s);
      if (mounted) setState(() => _sensitivity = s);
    } on AntiTheftDenied {
      _toPaywall();
    }
  }

  Future<void> _toggleCharger(bool value) async {
    try {
      await _service.setChargerDetection(value);
      if (mounted) setState(() => _chargerDetection = value);
    } on AntiTheftDenied {
      _toPaywall();
    }
  }

  void _toPaywall() {
    Navigator.of(
      context,
    ).pushNamed(ProGate.paywallRoute, arguments: PaywallSource.antiTheft);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Anti-theft mode')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return ValueListenableBuilder<EntitlementTier>(
      valueListenable: MonetizationService.instance.tierListenable,
      builder: (context, _, __) {
        if (!_allowed) {
          return Scaffold(
            appBar: AppBar(title: const Text('Anti-theft mode')),
            body: Center(
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ProBadge(),
                      const SizedBox(height: 12),
                      Text(
                        'Anti-theft protection is a GeoWake Pro feature.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _toPaywall,
                        child: const Text('Unlock GeoWake Pro'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Anti-theft mode')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              // Info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield,
                      color: scheme.onSecondaryContainer,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sleep safely on transit',
                            style: TextStyle(
                              color: scheme.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Anti-theft mode uses your phone\'s motion sensors to '
                            'detect if someone snatches or quickly moves your phone '
                            'while you sleep. A loud alarm can warn you when strong '
                            'snatch-like motion is detected and help wake you up.',
                            style: TextStyle(
                              color: scheme.onSecondaryContainer,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Enable toggle
              SwitchListTile(
                secondary: const Icon(Icons.security),
                title: const Text('Enable anti-theft protection'),
                subtitle: const Text(
                  'Monitors for phone movement while you sleep on transit',
                ),
                value: _enabled,
                onChanged: _toggle,
              ),
              const Divider(height: 32),

              // Sensitivity
              if (_enabled) ...[
                Text(
                  'Sensitivity',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Higher sensitivity detects lighter touches but may trigger '
                  'on bumpy roads. Medium is recommended for most transit.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                SegmentedButton<AntiTheftSensitivity>(
                  segments: const [
                    ButtonSegment(
                      value: AntiTheftSensitivity.low,
                      label: Text('Low'),
                      icon: Icon(Icons.bedtime),
                    ),
                    ButtonSegment(
                      value: AntiTheftSensitivity.medium,
                      label: Text('Medium'),
                      icon: Icon(Icons.directions_bus),
                    ),
                    ButtonSegment(
                      value: AntiTheftSensitivity.high,
                      label: Text('High'),
                      icon: Icon(Icons.warning_amber),
                    ),
                  ],
                  selected: {_sensitivity},
                  onSelectionChanged: (s) => _setSensitivity(s.first),
                ),
                const SizedBox(height: 24),

                // Charger removal detection
                SwitchListTile(
                  secondary: const Icon(Icons.power),
                  title: const Text('Charger removal alert'),
                  subtitle: const Text(
                    'Fires alarm if someone unplugs your phone while charging in public',
                  ),
                  value: _chargerDetection,
                  onChanged: _toggleCharger,
                ),
                const Divider(height: 32),

                // How it works
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: scheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'How it works',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '1. Anti-theft activates automatically when you start tracking\n'
                        '2. A 5-second calibration learns your current motion baseline\n'
                        '3. Accelerometer + gyroscope detect snatch patterns (grab + twist)\n'
                        '4. Adaptive Z-score adjusts to bumpy vs smooth transit\n'
                        '5. A loud alarm fires when the evidence crosses the threshold\n'
                        '6. Reliability varies by phone maker, battery policy, and lock state',
                        style: TextStyle(fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Active status
                if (_service.isMonitoring)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _service.isCalibrating
                              ? Icons.hourglass_top
                              : Icons.sensors,
                          color: scheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _service.isCalibrating
                              ? 'Calibrating — learning your motion baseline…'
                              : 'Monitoring active — your phone is protected',
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
