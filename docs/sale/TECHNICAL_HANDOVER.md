# Corpus reproduction notes

This is an archived engineering corpus for AI training and evaluation. Setup
instructions help a buyer inspect and exercise the existing code. They are not
a product launch plan, a deployment engagement, or a promise of additional
development by the seller.

The app targets Android first. Core tracking sits in
`lib/services/trackingservice.dart`; sensor fusion and the EKF sit under
`lib/core/ekf/`; the reachability model sits under `lib/core/reachability/`.
Alarm delivery is in `notification_service.dart`, `alarm_player.dart`, and
`packages/wakepoint_native/`. `geowake-server/` supplies the Express API;
`backend/share/` is a separate journey-sharing service.

## Reproduce headless verification

Use Flutter **3.44.6 / Dart 3.12.2** and Python 3. The captured backend manifest requests Node 24.x; local verification uses
Node 24.21.0. Older commits requested Node 18.x. Historical environment choices
remain part of the development record.

```bash
flutter pub get
python3 tools/sale/verify.py --profile code --out /tmp/geowake-verification
```

The runner defaults to two Flutter test workers to keep resource use bounded.
The runner captures commands, exit codes, timestamps and log hashes. Its API
test keys are explicit dummy values. It runs static analysis, the selected Flutter
suite with coverage, the Express suite and the share suite. In the cleaned export,
`--profile code` excludes eight explicitly listed dataset-dependent files. The
full original test source is retained; `--profile full` attempts all cases and
needs the withheld datasets. See `tools/sale/dataset-dependent-tests.json`. It does not launch
production services or exercise a buyer's billing credentials.

The historical full suite includes replay, reachability, route-scale,
playground, monotonic-clock and metro-integrity tests. Current corpus CI runs
the explicitly bounded code profile; it excludes the data-dependent gates. Some tests
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
`APP_BUNDLE_ID=com.geowake.app`. The test runner uses the same bundle ID with explicit dummy credentials. Real Maps calls may
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

The captured source check at `49a98bc` measured 11,436/16,800 Flutter lines
(68.07%) in 133 instrumented files, against 185 Dart files under `lib/`.
Express coverage was 303/417 lines (72.66%) in 16 files. These are measured-file
denominators. The older `42de864` run measured a different source tree and must
not be substituted for this result. Final sanitized-export evidence is separate.

The source check passed 1,466 visible Flutter tests, 61 Express tests and
16 sharing tests. The receipt names the two-worker command, SDK, timestamp and
log hashes. An earlier high-concurrency attempt ended without a completion
receipt after a timing assertion and coverage-service errors; its partial log
is preserved privately and is not counted as a completed run.

## Interpretation of the archived work

Headless test results concern code behavior under the supplied test inputs.
They do not measure physical-device alarm delivery, underground localization
accuracy, store billing, or OEM background behavior. Those distinctions are
useful when constructing training or evaluation tasks from the archive.

The latest pre-existing recovery, tracking, billing and release-policy work was
captured in `f4daa94`. `LOCAL_WORK_CAPTURE.md` records that provenance and the
subsequent reproduction repairs. Baseline results are not relabelled as checks
of the capture. Historical commercial plans remain context, not a commitment.

Dataset collection and further product development stopped for economic
reasons, according to the founder. The transaction concerns the existing
engineering material; no additional field collection or launch work is
required to understand that material.

Source-only ZIPs can run the same verification helper. Their receipt records
`source_mode: source-archive` and no Git revision, rather than borrowing a
parent directory's repository identity. Use the external file manifest to match
such an extracted archive to its offered revision.
