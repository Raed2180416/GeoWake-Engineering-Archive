// Integration test for the assembled MonetizationService facade (headless:
// mocked SharedPreferences + FakePurchaseBackend). Verifies entitlement load,
// purchase flow, and the ad ride-counter — without any real store/ad SDK.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:geowake2/services/monetization/monetization_service.dart';
import 'package:geowake2/services/monetization/premium_service.dart';
import 'package:geowake2/services/monetization/purchase_backend.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MonetizationService.instance.resetForTesting();
    MonetizationService.instance.premium = PremiumService(
      backend: FakePurchaseBackend(),
    );
  });

  test(
    'first-user offer grants every Pro gate for exactly one fixed window',
    () async {
      final svc = MonetizationService.instance;
      await svc.init(
        backendOverride: FakePurchaseBackend(),
        enableFirstUserTrial: true,
      );

      expect(svc.isFirstUserTrialActive, isTrue);
      expect(svc.premium.isPro, isTrue);
      expect(svc.premium.isAdFree, isTrue);
      expect(svc.premium.canUseCustomAlarmSounds, isTrue);
      expect(svc.premium.canUseWidget, isTrue);
      expect(svc.premium.canUseGuardianMode, isTrue);
      expect(svc.premium.canUseAntiTheft, isTrue);
      expect(svc.premium.canUseCoreAlarm, isTrue);

      final prefs = await SharedPreferences.getInstance();
      final started = prefs.getInt(
        MonetizationService.firstUserTrialStartedKey,
      );
      expect(started, isNotNull);

      // Reinitialization must not slide/extend the seven-day window.
      final persisted = <String, Object>{};
      for (final key in prefs.getKeys()) {
        final value = prefs.get(key);
        if (value != null) persisted[key] = value;
      }
      svc.resetForTesting();
      SharedPreferences.setMockInitialValues(persisted);
      await svc.init(
        backendOverride: FakePurchaseBackend(),
        enableFirstUserTrial: true,
      );
      expect(
        (await SharedPreferences.getInstance()).getInt(
          MonetizationService.firstUserTrialStartedKey,
        ),
        started,
      );
    },
  );

  test('assembles a free user by default; core alarm always usable', () async {
    final fake = FakePurchaseBackend()..buyShouldSucceed = true;
    final svc = MonetizationService.instance;
    // Force re-init path by constructing a fresh premium through init override.
    await svc.init(backendOverride: fake);
    expect(svc.premium.isPro, isFalse);
    expect(svc.premium.canUseCoreAlarm, isTrue);
    expect(svc.premium.isAdFree, isFalse);
  });

  test('ride counter persists and resets on ad shown', () async {
    SharedPreferences.setMockInitialValues({});
    final svc = MonetizationService.instance;
    await svc.markAdShown();
    expect(svc.ridesSinceLastAd, 0);
    await svc.recordRide();
    await svc.recordRide();
    expect(svc.ridesSinceLastAd, 2);
    // Persisted across a fresh SharedPreferences read.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('gw_rides_since_last_ad'), 2);
    await svc.markAdShown();
    expect(svc.ridesSinceLastAd, 0);
  });

  test('buying Pro through the fake backend flips premium gates', () async {
    final fake = FakePurchaseBackend()..buyShouldSucceed = true;
    final premium = PremiumService(backend: fake);
    expect(premium.isPro, isFalse);
    final ok = await premium.buyPro();
    expect(ok, isTrue);
    expect(premium.isPro, isTrue);
    expect(premium.isAdFree, isTrue);
    // Core reliability is free regardless.
    expect(premium.canUseCoreAlarm, isTrue);
  });

  test(
    'daily sponsor gate opens before trip four, once per local day',
    () async {
      final svc = MonetizationService.instance;
      svc.resetForTesting();
      SharedPreferences.setMockInitialValues({});
      await svc.init(backendOverride: FakePurchaseBackend());

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 12);
      expect(svc.shouldShowPreTripSponsor(now: today), isFalse);

      await svc.recordRide(now: today);
      await svc.recordRide(now: today);
      expect(svc.completedRidesToday, 2);
      expect(svc.shouldShowPreTripSponsor(now: today), isFalse);

      await svc.recordRide(now: today);
      expect(svc.shouldShowPreTripSponsor(now: today), isTrue);
      await svc.markPreTripSponsorShown(now: today);
      expect(svc.shouldShowPreTripSponsor(now: today), isFalse);

      final tomorrow = today.add(const Duration(days: 1));
      expect(svc.shouldShowPreTripSponsor(now: tomorrow), isFalse);
      await svc.recordRide(now: tomorrow);
      await svc.recordRide(now: tomorrow);
      await svc.recordRide(now: tomorrow);
      expect(svc.shouldShowPreTripSponsor(now: tomorrow), isTrue);

      await svc.premium.buyPro();
      expect(
        svc.shouldShowPreTripSponsor(now: tomorrow),
        isFalse,
        reason: 'every paid pass is ad-free',
      );
    },
  );
}
