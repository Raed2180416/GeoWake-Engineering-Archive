// Post-arrival monetization regression tests. Forced interstitials belong only
// at the announced pre-trip-four checkpoint; this screen may offer an optional
// rewarded day pass, but must remain usable and must show no monetization to Pro.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:geowake2/screens/monetization/post_arrival_screen.dart';
import 'package:geowake2/services/monetization/monetization_service.dart';
import 'package:geowake2/services/monetization/post_arrival_service.dart';
import 'package:geowake2/services/monetization/premium_service.dart';
import 'package:geowake2/services/monetization/purchase_backend.dart';

Widget _host(PostArrivalCard card) {
  return MaterialApp(
    initialRoute: '/postArrival',
    routes: {
      '/': (_) => const Scaffold(body: Center(child: Text('HOME'))),
      '/postArrival': (_) => PostArrivalScreen(card: card),
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mon = MonetizationService.instance;

  setUpAll(() async {
    // MonetizationService.init() reads/writes SharedPreferences (the ride
    // counter, PremiumService persistence) — without a mock store, those
    // calls hit a real, unregistered platform channel headless.
    SharedPreferences.setMockInitialValues({});
    await mon.init(backendOverride: FakePurchaseBackend());
  });

  testWidgets(
      'a free user may opt into the rewarded day-pass after arrival',
      (tester) async {
    mon.premium = PremiumService(backend: FakePurchaseBackend());
    // Drive ridesSinceLastAd to the cap (3) via the real facade counter.
    await mon.markAdShown(); // reset to a known 0 first
    await mon.recordRide();
    await mon.recordRide();
    await mon.recordRide();
    expect(mon.ridesSinceLastAd, 3);

    final card = PostArrivalService.build(stationName: 'Indiranagar');
    await tester.pumpWidget(_host(card));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('post_arrival_screen_title')), findsOneWidget);
    expect(find.byKey(const Key('post_arrival_rewarded_strip')), findsOneWidget);
  });

  testWidgets(
      'optional rewarded offer does not depend on the forced-ad trip counter',
      (tester) async {
    mon.premium = PremiumService(backend: FakePurchaseBackend());
    await mon.markAdShown(); // ridesSinceLastAd -> 0, below the cap of 3

    final card = PostArrivalService.build(stationName: 'MG Road');
    await tester.pumpWidget(_host(card));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('post_arrival_rewarded_strip')), findsOneWidget);
  });

  testWidgets(
      'a Pro user sees no rewarded strip', (tester) async {
    mon.premium = PremiumService(backend: FakePurchaseBackend());
    await mon.premium.buyPro();
    await mon.markAdShown();
    await mon.recordRide();
    await mon.recordRide();
    await mon.recordRide();

    final card = PostArrivalService.build(stationName: 'Whitefield');
    await tester.pumpWidget(_host(card));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('post_arrival_screen_title')), findsOneWidget);
    expect(find.byKey(const Key('post_arrival_rewarded_strip')), findsNothing,
        reason: 'Pro must never see any monetization surface here');
  });

  testWidgets(
      'tapping Watch on the rewarded strip fails open headless', (tester) async {
    mon.premium = PremiumService(backend: FakePurchaseBackend());
    await mon.markAdShown();
    await mon.recordRide();
    await mon.recordRide();
    await mon.recordRide();

    final card = PostArrivalService.build(stationName: 'Koramangala');
    await tester.pumpWidget(_host(card));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('post_arrival_rewarded_strip')), findsOneWidget);
    await tester.tap(find.text('Watch'));
    await tester.pumpAndSettle();

    // AdService.showRewarded is fail-open headless too — the screen must
    // still be alive and responsive afterwards.
    expect(find.byKey(const Key('post_arrival_screen_title')), findsOneWidget);
  });
}
