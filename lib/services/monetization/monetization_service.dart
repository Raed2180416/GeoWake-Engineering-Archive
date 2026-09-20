// lib/services/monetization/monetization_service.dart
//
// App-level facade that assembles the monetization stack: PremiumService (the
// unit-tested entitlement logic) backed by the real store adapter and
// SharedPreferences persistence, plus the ride counter that drives the ad
// frequency cap. Everything degrades gracefully — if the store is unavailable
// or prefs fail, the user is simply a free (never a broken) user, and the core
// alarm is never affected (PremiumService.canUseCoreAlarm is always true).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_service.dart';
import 'premium_service.dart';
import 'purchase_backend.dart';
import 'purchase_backend_impl.dart';

class MonetizationService {
  MonetizationService._();
  static final MonetizationService instance = MonetizationService._();

  static const String _ridesKey = 'gw_rides_since_last_ad';
  static const String _dailyRidesKey = 'gw_completed_rides_today';
  static const String _dailyRidesDateKey = 'gw_completed_rides_local_date';
  static const String _sponsorShownDateKey = 'gw_sponsor_shown_local_date';
  static const String firstUserTrialStartedKey =
      'gw_first_user_trial_started_at_v1';
  static const String firstUserTrialWelcomeSeenKey =
      'gw_first_user_trial_welcome_seen_v1';
  static const Duration firstUserTrialDuration = Duration(days: 7);

  /// Hardcoded fallback price shown if the store metadata is unavailable, so the
  /// paywall CTA never blanks. Retained for the legacy one-time SKU; the pass
  /// ladder carries its own per-SKU fallbacks in the paywall. Play Console must
  /// configure geowake_pro_daily/weekly/monthly/yearly as prepaid subscriptions
  /// at ₹7/35/99/899.
  static const String proPriceFallback = '₹199';

  late PremiumService premium;
  PurchaseBackend? _backend;
  IapPurchaseBackend? _iapBackend;
  bool _ready = false;
  int _firstUserTrialStartedAtMs = 0;

  /// Reactive set of product IDs with a PENDING purchase (e.g. UPI processing).
  /// UI observes this to show "Payment processing…" banners.
  final ValueNotifier<Set<String>> pendingPurchasesListenable =
      ValueNotifier<Set<String>>(<String>{});

  /// Reactive entitlement tier. UI wraps this in a [ValueListenableBuilder] so a
  /// purchase / rewarded day-pass instantly hides ads + unlocks Pro with no
  /// restart. UI MUST mutate entitlement through this facade (buyPro /
  /// restorePurchases / grantRewardedDayPass), never PremiumService directly, so
  /// the notifier stays in sync.
  final ValueNotifier<EntitlementTier> tierListenable =
      ValueNotifier<EntitlementTier>(EntitlementTier.free);

  void _syncTier() {
    tierListenable.value = _ready ? premium.tier : EntitlementTier.free;
  }

  /// True once [init] has assembled the entitlement stack.
  bool get isReady => _ready;

  @visibleForTesting
  void resetForTesting() {
    _backend = null;
    _iapBackend = null;
    _ready = false;
    _ridesSinceLastAd = 0;
    _completedRidesToday = 0;
    _completedRidesDate = '';
    _sponsorShownDate = '';
    _firstUserTrialStartedAtMs = 0;
    pendingPurchasesListenable.value = <String>{};
    tierListenable.value = EntitlementTier.free;
  }

  /// Safe accessor for callers that may run before [init] completes (e.g. a
  /// banner widget mounting at first paint) — null until ready.
  PremiumService? get premiumOrNull => _ready ? premium : null;

  bool get isFirstUserTrialActive {
    if (_firstUserTrialStartedAtMs <= 0) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiry =
        _firstUserTrialStartedAtMs + firstUserTrialDuration.inMilliseconds;
    return now >= _firstUserTrialStartedAtMs && now < expiry;
  }

  DateTime? get firstUserTrialEndsAt =>
      _firstUserTrialStartedAtMs <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
            _firstUserTrialStartedAtMs + firstUserTrialDuration.inMilliseconds,
          );

  int _ridesSinceLastAd = 0;
  int get ridesSinceLastAd => _ridesSinceLastAd;

  int _completedRidesToday = 0;
  String _completedRidesDate = '';
  String _sponsorShownDate = '';

  /// Completed, fully-ended trips in the rider's current local calendar day.
  /// This is the production counter for the "three free trips, sponsor before
  /// trip four" contract. The older since-last-ad counter remains only for
  /// backward-compatible telemetry/tests while call sites migrate.
  int get completedRidesToday {
    _rollDailyState(DateTime.now());
    return _completedRidesToday;
  }

  /// Assemble + load entitlement. Call once at app start before reading gates.
  /// [backendOverride] lets tests inject a FakePurchaseBackend.
  Future<void> init({
    PurchaseBackend? backendOverride,
    bool? enableFirstUserTrial,
  }) async {
    if (_ready) return;
    final offerTrial = enableFirstUserTrial ?? backendOverride == null;
    try {
      if (backendOverride != null) {
        _backend = backendOverride;
      } else {
        final iap = IapPurchaseBackend();
        await iap.init();
        _backend = iap;
        _iapBackend = iap;
      }
      premium = PremiumService(
        backend: _backend!,
        load: (k) async => (await SharedPreferences.getInstance()).getString(k),
        save:
            (k, v) async =>
                (await SharedPreferences.getInstance()).setString(k, v),
      );
      // Grant Pro whenever ownership arrives asynchronously (a UPI/pending
      // purchase that clears after buyPro timed out, or a late restore). Sync
      // the reactive tier so a late-arriving purchase instantly unlocks the UI.
      _backend!.onEntitlementChanged = (owned) async {
        await premium.applyOwnedProducts(owned);
        _syncTier();
      };
      // Wire pending purchase tracking (UPI-specific) so the UI can show
      // "Payment processing…" banners. Critical for India payment flows.
      _iapBackend?.onPendingChanged = (pendingIds) {
        pendingPurchasesListenable.value = Set<String>.from(pendingIds);
      };
      await premium.load();
      final prefs = await SharedPreferences.getInstance();
      if (offerTrial) await _loadOrStartFirstUserTrial(prefs);
      _ridesSinceLastAd = prefs.getInt(_ridesKey) ?? 0;
      _completedRidesDate = prefs.getString(_dailyRidesDateKey) ?? '';
      _completedRidesToday = prefs.getInt(_dailyRidesKey) ?? 0;
      _sponsorShownDate = prefs.getString(_sponsorShownDateKey) ?? '';
      if (_rollDailyState(DateTime.now())) {
        await _persistDailyState(prefs);
      }
      _ready = true;
      _syncTier();
      // Reconcile purchases completed while the app wasn't running (e.g. a
      // UPI payment that cleared overnight). Fire-and-forget so it never
      // blocks startup. Google recommends this on every app launch.
      unawaited(_iapBackend?.queryPastPurchases());
      // Ad SDK init is slow and non-essential — never block startup on it.
      // ignore: discarded_futures
      AdService.instance.init();
    } catch (_) {
      // Fall back to a free, in-memory-backed premium so the app still runs.
      _backend ??= FakePurchaseBackend();
      premium = PremiumService(
        backend: _backend!,
        load: (k) async => (await SharedPreferences.getInstance()).getString(k),
        save:
            (k, v) async =>
                (await SharedPreferences.getInstance()).setString(k, v),
      );
      if (offerTrial) {
        try {
          await premium.load();
          await _loadOrStartFirstUserTrial(
            await SharedPreferences.getInstance(),
          );
        } catch (_) {}
      }
      _ready = true;
      _syncTier();
    }
  }

  Future<void> _loadOrStartFirstUserTrial(SharedPreferences prefs) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    var started = prefs.getInt(firstUserTrialStartedKey) ?? 0;
    if (started <= 0) {
      started = now;
      await prefs.setInt(firstUserTrialStartedKey, started);
    }
    _firstUserTrialStartedAtMs = started;
    final expiry = started + firstUserTrialDuration.inMilliseconds;
    // A backwards wall-clock jump never mints access. Server-side eligibility
    // is still required before launch to prevent reinstall/clock abuse.
    if (now >= started && now < expiry) {
      await premium.grantPromotionalAccessUntil(expiry);
    }
  }

  // ── Entitlement mutations — call THESE from UI, not PremiumService, so the
  //    reactive [tierListenable] stays in sync. ──────────────────────────────

  /// Buy the one-time Pro unlock. Returns true iff granted.
  /// Returns false on cancel, error, or timeout. For UPI pending purchases,
  /// the [pendingPurchasesListenable] will fire so the UI can show a
  /// "Payment processing…" banner — the purchase may still complete later.
  Future<bool> buyPro() async {
    if (!_ready) return false;
    final ok = await premium.buyPro();
    _syncTier();
    return ok;
  }

  /// Restore prior purchases (reinstall / new device). Returns owned product ids.
  Future<Set<String>> restorePurchases() async {
    if (!_ready) return <String>{};
    final owned = await premium.restorePurchases();
    _syncTier();
    return owned;
  }

  /// Buy a prepaid pass (daily/weekly/monthly/yearly — [PremiumProducts.passLadder]).
  /// It remains restorable and can be topped up. Returns true iff the Play token
  /// was verified by GeoWake's backend and an active expiry was returned.
  /// Like [buyPro], a UPI-pending purchase resolves false here but may still
  /// clear later via [pendingPurchasesListenable] → entitlement stream.
  Future<bool> buyPass(String productId) async {
    if (!_ready) return false;
    final ok = await premium.buyPass(productId);
    _syncTier();
    return ok;
  }

  /// Grant a rewarded "Pro for a day" pass (call after a rewarded video completes).
  Future<void> grantRewardedDayPass({
    Duration duration = PremiumService.rewardedDayPassDuration,
  }) async {
    if (!_ready) return;
    await premium.grantRewardedDayPass(duration: duration);
    _syncTier();
  }

  /// Localized price for a specific SKU (pass ladder or one-time), falling back
  /// to [fallback] if store metadata is unavailable so the paywall never blanks.
  Future<String> priceOrFallback(String productId, String fallback) async {
    try {
      final p = await _backend?.queryPrice(productId);
      if (p != null && p.trim().isNotEmpty) return p;
    } catch (_) {
      /* fall through */
    }
    return fallback;
  }

  /// Localized Pro price string, falling back to [proPriceFallback] if the store
  /// metadata is unavailable — so the paywall CTA never blanks or crashes.
  Future<String> proPriceOrFallback() async {
    try {
      final p = await _backend?.queryPrice(PremiumService.proProductId);
      if (p != null && p.trim().isNotEmpty) return p;
    } catch (_) {
      /* fall through */
    }
    return proPriceFallback;
  }

  /// Count a completed ride and persist it (drives the ad frequency cap).
  Future<void> recordRide({DateTime? now}) async {
    final localNow = now ?? DateTime.now();
    _rollDailyState(localNow);
    _ridesSinceLastAd++;
    _completedRidesToday++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_ridesKey, _ridesSinceLastAd);
      await _persistDailyState(prefs);
    } catch (_) {
      /* best effort */
    }
  }

  /// Whether a free rider should see the announced sponsor checkpoint before
  /// arming their next trip. It appears once per local day, after three trips
  /// have fully completed. Pro users never enter the checkpoint.
  bool shouldShowPreTripSponsor({DateTime? now}) {
    if (!_ready || premium.isPro) return false;
    final localNow = now ?? DateTime.now();
    final changed = _rollDailyState(localNow);
    if (changed) {
      // Persist lazily; a date rollover must never block the arm flow.
      unawaited(_persistDailyStateBestEffort());
    }
    final today = _localDateKey(localNow);
    return _completedRidesToday >= 3 && _sponsorShownDate != today;
  }

  /// Mark the daily sponsor as actually displayed. Failed/no-fill requests do
  /// not call this, so a later trip may retry while the current trip proceeds.
  Future<void> markPreTripSponsorShown({DateTime? now}) async {
    final localNow = now ?? DateTime.now();
    _rollDailyState(localNow);
    _sponsorShownDate = _localDateKey(localNow);
    await _persistDailyStateBestEffort();
  }

  /// Reset the counter after an ad was shown.
  Future<void> markAdShown() async {
    _ridesSinceLastAd = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_ridesKey, 0);
    } catch (_) {
      /* best effort */
    }
  }

  bool _rollDailyState(DateTime now) {
    final today = _localDateKey(now);
    if (_completedRidesDate == today) return false;
    _completedRidesDate = today;
    _completedRidesToday = 0;
    return true;
  }

  static String _localDateKey(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }

  Future<void> _persistDailyState(SharedPreferences prefs) async {
    await prefs.setString(_dailyRidesDateKey, _completedRidesDate);
    await prefs.setInt(_dailyRidesKey, _completedRidesToday);
    await prefs.setString(_sponsorShownDateKey, _sponsorShownDate);
  }

  Future<void> _persistDailyStateBestEffort() async {
    try {
      await _persistDailyState(await SharedPreferences.getInstance());
    } catch (_) {
      /* best effort */
    }
  }
}
