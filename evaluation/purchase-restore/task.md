# Concurrent purchase restore: retrospective coding task

Written 20 September 2026 from GeoWake Git history. This is a new task prompt, not a historical issue or customer report.

At app launch, `queryPastPurchases()` can already be waiting for the store purchase stream when a user starts `restore()`. A single restored-purchase stream event must promptly satisfy both in-flight calls. The user-triggered call must return the owned product IDs. Keep single and later restore calls working, and preserve bounded timeout and cleanup when a restore produces no event.

Edit `lib/services/monetization/purchase_backend_impl.dart`. Run the supplied, unchanged `test/monetization/purchase_backend_impl_test.dart` with Flutter. The package here contains only the store adapter, its interface, and the original regression test. The test uses a fake store platform; no account, payment, server, API key, or device is needed.

The test file is from the historical fix commit and its comments describe the historical repair. This makes the example suitable for transparent coding practice, not a blind benchmark.
