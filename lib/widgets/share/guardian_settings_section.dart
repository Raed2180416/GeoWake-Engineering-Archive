// lib/widgets/share/guardian_settings_section.dart
//
// A Settings row for Guardian mode (Pro). Locked rows carry a ProBadge and route
// through the single ProGate.run choke point to the paywall; unlocked users go
// to the Guardian setup screen. Reactive to entitlement + Guardian on/off.

import 'package:flutter/material.dart';

import '../../services/monetization/monetization_service.dart';
import '../../services/monetization/premium_service.dart';
import '../../services/share/guardian_service.dart';
import '../monetization/pro_gate.dart';

/// The named route the setup screen is registered under (see wiring notes).
const String guardianRoute = '/guardian';

class GuardianSettingsSection extends StatelessWidget {
  const GuardianSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final mon = MonetizationService.instance;
    return ValueListenableBuilder<EntitlementTier>(
      valueListenable: mon.tierListenable,
      builder: (context, _, __) {
        final allowed = mon.premiumOrNull?.canUseGuardianMode ?? false;
        return ValueListenableBuilder<bool>(
          valueListenable: GuardianService.instance.enabledListenable,
          builder: (context, guardianOn, ___) {
            final automatic = GuardianService.instance.hasAutomaticDelivery;
            return ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Guardian mode'),
              subtitle: Text(
                allowed
                    ? (guardianOn
                        ? (automatic
                            ? 'On — your saved contact is notified automatically'
                            : 'On — a ready-to-send live link opens when you arm')
                        : (automatic
                            ? 'Auto-share every commute with someone you trust'
                            : 'Prepare a live link for someone you trust'))
                    : 'Live commute links + "arrived safely" — GeoWake Pro',
              ),
              trailing:
                  allowed ? const Icon(Icons.chevron_right) : const ProBadge(),
              onTap:
                  () => ProGate.run(
                    context,
                    allowed: allowed,
                    source: PaywallSource.guardian,
                    onAllowed:
                        () => Navigator.of(context).pushNamed(guardianRoute),
                  ),
            );
          },
        );
      },
    );
  }
}
