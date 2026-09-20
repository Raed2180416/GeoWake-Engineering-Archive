// lib/services/monetization/purchase_backend.dart
//
// The billing seam for the monetization layer. The concrete `in_app_purchase`
// implementation is wired in centrally during integration — this file (and the
// whole monetization module) NEVER imports the platform SDK, so the entitlement
// logic stays pure and unit-testable headless.
//
// The launch products are Google Play prepaid subscriptions: daily, weekly,
// monthly, and yearly. A legacy one-time unlock remains restorable for anyone
// who already owns it, but it is not part of the v1 paywall.

import 'dart:async';

/// Where entitlement purchases actually happen. Implemented by a concrete
/// `in_app_purchase`-backed class at integration time; faked in tests.
abstract class PurchaseBackend {
  /// Fired whenever the set of owned product ids changes on the store's
  /// ASYNCHRONOUS purchase stream — crucially including a PENDING purchase
  /// (UPI / netbanking, the dominant rails in India) that CLEARS long after
  /// [buyOneTime] already timed out and returned false. Wire this to
  /// PremiumService so a late-arriving purchase still grants Pro instead of
  /// leaving a paying user on Free until a manual restore.
  void Function(Set<String> owned)? onEntitlementChanged;

  /// Server-authoritative expiry (epoch ms) for every currently verified
  /// prepaid subscription. Paid access must be derived from this map, never
  /// from a locally calculated duration.
  Map<String, int> get verifiedPassExpiries;

  /// Attempt a one-time (non-consumable) purchase of [productId].
  ///
  /// Returns `true` iff the purchase completed and the entitlement is now owned
  /// by the store account. Implementations should return `false` (not throw) on
  /// user-cancel; genuine errors may throw and are handled by the caller.
  Future<bool> buyOneTime(String productId);

  /// Buy a Google Play prepaid subscription. Returns true only after the Play
  /// purchase token has been verified by GeoWake's backend and an authoritative
  /// expiry has been placed in [verifiedPassExpiries]. The store purchase stays
  /// restorable; it is never consumed as an in-app product.
  Future<bool> buyPrepaidSubscription(String productId);

  /// Restore previously-owned non-consumable purchases (e.g. after reinstall or
  /// on a new device signed into the same store account).
  ///
  /// Returns the set of owned product ids — empty if nothing is owned. Must not
  /// throw for the "nothing to restore" case.
  Future<Set<String>> restore();

  /// The localized store price string for [productId] (e.g. "₹199.00"), or null
  /// if the store metadata is unavailable. Callers MUST fall back to a hardcoded
  /// price so a metadata failure never blanks the paywall CTA.
  Future<String?> queryPrice(String productId);
}

/// In-memory [PurchaseBackend] for tests and headless runs. Deterministic and
/// SDK-free: it records every call and lets a test script success/decline/throw.
class FakePurchaseBackend implements PurchaseBackend {
  @override
  void Function(Set<String> owned)? onEntitlementChanged;

  final Set<String> _owned;
  final int Function() _nowMs;

  @override
  final Map<String, int> verifiedPassExpiries = <String, int>{};

  /// When `false`, [buyOneTime] resolves `false` (simulates a user-cancel or a
  /// declined charge) and does NOT grant ownership.
  bool buyShouldSucceed;

  /// When `true`, [buyOneTime] throws (simulates a billing error).
  bool throwOnBuy;

  /// Call log — product ids passed to [buyPrepaidSubscription], in order.
  final List<String> subscriptionBuyCalls = <String>[];

  /// Legacy test accessor retained while old receipts are migrated.
  List<String> get consumableBuyCalls => subscriptionBuyCalls;

  /// When `true`, [restore] throws (simulates a restore error).
  bool throwOnRestore;

  /// Price string [queryPrice] returns (null simulates unavailable store
  /// metadata, exercising the caller's hardcoded fallback).
  String? priceString;

  /// Call log — product ids passed to [buyOneTime], in order.
  final List<String> buyCalls = <String>[];

  /// Number of times [restore] was invoked.
  int restoreCalls = 0;

  FakePurchaseBackend({
    Set<String>? initiallyOwned,
    this.buyShouldSucceed = true,
    this.throwOnBuy = false,
    this.throwOnRestore = false,
    this.priceString = '₹199.00',
    int Function()? nowMs,
  }) : _owned = <String>{...?initiallyOwned},
       _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// Products currently owned in the fake store (read-only view).
  Set<String> get owned => Set<String>.unmodifiable(_owned);

  @override
  Future<bool> buyOneTime(String productId) async {
    buyCalls.add(productId);
    if (throwOnBuy) {
      throw StateError('FakePurchaseBackend: buy failed for $productId');
    }
    if (!buyShouldSucceed) return false;
    _owned.add(productId);
    onEntitlementChanged?.call(<String>{..._owned});
    return true;
  }

  @override
  Future<bool> buyPrepaidSubscription(String productId) async {
    subscriptionBuyCalls.add(productId);
    if (throwOnBuy) {
      throw StateError(
        'FakePurchaseBackend: subscription buy failed for $productId',
      );
    }
    if (!buyShouldSucceed) return false;
    final duration = switch (productId) {
      'geowake_pro_daily' => const Duration(hours: 24),
      'geowake_pro_weekly' => const Duration(days: 7),
      'geowake_pro_monthly' => const Duration(days: 30),
      'geowake_pro_yearly' => const Duration(days: 365),
      _ => Duration.zero,
    };
    if (duration == Duration.zero) return false;
    final old = verifiedPassExpiries[productId] ?? 0;
    final base = old > _nowMs() ? old : _nowMs();
    final expiry = base + duration.inMilliseconds;
    verifiedPassExpiries[productId] = expiry;
    _owned.add(productId);
    onEntitlementChanged?.call(<String>{..._owned});
    return true;
  }

  /// Test hook: simulate a PENDING purchase clearing AFTER buyOneTime gave up —
  /// ownership arrives on the stream and must still grant entitlement.
  void simulateLatePurchase(String productId) {
    _owned.add(productId);
    onEntitlementChanged?.call(<String>{..._owned});
  }

  @override
  Future<Set<String>> restore() async {
    restoreCalls++;
    if (throwOnRestore) {
      throw StateError('FakePurchaseBackend: restore failed');
    }
    return <String>{..._owned};
  }

  @override
  Future<String?> queryPrice(String productId) async => priceString;
}
