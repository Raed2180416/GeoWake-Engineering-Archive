# Technical handover

The app targets Android first. Core tracking sits in
`lib/services/trackingservice.dart`; sensor fusion and the EKF sit under
`lib/core/ekf/`; the reachability model sits under `lib/core/reachability/`.
Alarm delivery is in `notification_service.dart`, `alarm_player.dart`, and
`packages/wakepoint_native/`. `geowake-server/` supplies the Express API;
`backend/share/` is a separate journey-sharing service.

## Reproduce headless verification

Use Flutter **3.44.6 / Dart 3.12.2** and Python 3. The historical backend
manifest requests Node 18.x; the September 20 local tests used Node 24.21.0.
That result is not a support promise for all Node versions. A supported-runtime
migration should be tested and reflected in the manifest before deployment.

```bash
flutter pub get
python3 tools/sale/verify.py --out /tmp/geowake-verification
```

The runner captures commands, exit codes, timestamps and log hashes. Its API
test keys are explicit dummy values. It runs static analysis, the full Flutter
suite with coverage, the Express suite and the share suite. It does not launch
production services or exercise a buyer's billing credentials.

The full Flutter suite includes the replay, reachability, route-scale,
playground, monotonic-clock and metro-integrity tests named in CI. Some tests
cannot observe native plugins in a headless process. The externally stored
real-ride replay branch returns early when its recordings are absent; a green
suite must not be described as fresh field validation.

## Use a buyer-controlled backend

`AppConfig.serverBaseUrl` and `ApiClient.baseUrl` now use the same build define:

```bash
flutter run --dart-define=GEOWAKE_API_BASE_URL=http://10.0.2.2:3000/api
```

`10.0.2.2` is Android emulator host-loopback. For a real phone use an appropriate
reachable development endpoint; production transport should use HTTPS. The
existing default points at the original Railway service, so set this define
for an independent evaluation. Do not copy the seller's API keys or tokens.

For the backend, supply your own environment through its existing `.env`
workflow: `GOOGLE_MAPS_API_KEY`, `JWT_SECRET` (at least 32 characters), and
`APP_BUNDLE_ID=com.geowake.app`. The test runner's legacy fixture bundle ID is
different and deliberately confined to test execution. Real Maps calls may
incur charges on the account whose key is supplied.

The share service has its own configuration. Core wake behavior must remain
available when optional share, monetization or data-asset services are absent.
Mobility consent remains default-off and aggregate egress remains disabled.

## Android artifacts

Current Gradle configuration uses compile SDK **36**, minimum SDK **24**,
target SDK **35**, and NDK **28.2.13676358**. Provision the matching Android
toolchain and local `android/key.properties` only for keys you control.

```bash
flutter build apk --debug
```

A debug APK is an evaluation artifact. The baseline release-APK command can
fall back to debug signing; do not call it a production-signed release. A
Play-bound AAB requires a properly configured release keystore. Build evidence
is supplied separately and should name the exact candidate revision.

## Coverage interpretation

The candidate run measured 10,610/15,699 lines in 127 Flutter coverage files
(67.58%) and 315/413 lines in 15 backend coverage files (76.27%). There are
182 Dart files under `lib/`, so this is instrumented-file coverage, not a claim
that 67.58% of the entire application was tested. Preserve the raw LCOV files
and state the denominator when importing metrics into a marketplace.

## Release work still requiring evidence

1. Exercise audible alarm delivery on physical devices: screen off, Doze,
   process death, reboot and permission-denial paths. Capture actual outcomes.
2. Resolve underground uncertainty with transferable recordings, independent
   ground truth and held-out routes; synthetic inputs do not replace this.
3. Review unfinished local changes before selecting a final production branch.
   They include recovery, tracking, billing and release-policy work absent
   from this candidate's baseline.
4. Reconcile production legal copy with prepaid entitlements and verify Play
   sandbox purchases and restoration. The original README's lifetime-price
   claim was stale; no live pricing/fulfillment claim is made here.
5. Clear or replace mixed-source geography and artwork, sanitize delivered
   history, and retain third-party notices.

These gaps do not prevent reviewing the software as an engineering asset.
They do prevent describing it as a fully validated underground product.
