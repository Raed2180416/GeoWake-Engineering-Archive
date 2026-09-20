# GeoWake — never miss your stop

I built GeoWake around a familiar problem: wanting to sleep, read or stop
watching the map during a commute without missing the destination. A passenger
chooses a route and a distance, time or stops threshold; the app tracks the
journey and prepares the wake alarm.

I am offering the existing Flutter/Dart app, native Android integration, two
Node backends, development history, experiments and tests for model training
and software-engineering evaluation. The package includes the decisions and
failures that explain how the systems developed. Ongoing product development
and deployment are outside the proposed transaction.

## From the passenger journey to the engineering

| Passenger need | Engineering represented in the archive |
|---|---|
| Find the destination and choose a journey | Search, saved trips, route comparison, caching, destination/transfer handling |
| Be warned before boarding or arriving | Experimental pre-boarding thresholds; distance, time and stops modes; intermediate journey events |
| Keep track when the route changes | Route identity, map snapping, progress, sustained-deviation detection and rerouting |
| Receive the alarm while using another app | Background location, session recovery, full-screen alerts, sound/vibration and an Android exact-alarm backstop |
| Use related journey features | Sharing, guardian, anti-theft, home-widget handoff, purchase/restore flows and consent-gated aggregation |

The [feature guide](FEATURES.md) identifies implemented behavior, optional
integrations and unfinished work. The [journey guide](JOURNEY_AND_ROUTING.md)
and [data-flow map](DATA_FLOW.md) trace inputs through route state, sensors,
storage, APIs and alarm delivery. They also explain how optional features are
kept out of the core alarm's critical path.

## Underground tracking: the central research problem

Above ground, the app worked mostly well in my use. Underground, GPS loss made
progress estimation much harder. I initially wanted to combine GPS with IMU
measurements to follow the whole route and continue through tunnels. Normal
phone handling introduced motion that was difficult to separate from the
train's acceleration. Small orientation and bias errors then accumulated into
large speed and distance errors.

That motivated a more constrained question: could the stronger pattern of a
train braking, dwelling and accelerating again indicate progress through a
known station sequence? Instead of trusting continuous integration to recover
every metre, the experimental direction used stop-related events and route
structure as possible anchors. A detected zero velocity still does not tell
us which station it is, and a signal stop is not necessarily a platform stop.

The archive preserves six connected parts of this investigation:

- **Raw IMU integration and its replacement.** The earliest prototype
  integrated phone axes with damping and periodic reset; it did not yet fuse
  GPS corrections. The later route-constrained EKF implemented GPS/IMU fusion.
- **Position, speed and uncertainty.** Route geometry, accelerometer bias,
  covariance, GPS quality gates, sensor gaps and cold starts appear in code
  and constructed-input tests.
- **ZUPT and station association.** The history includes a false-stop defect
  during smooth cruising, its correction, and gates for ambiguity, forward
  progress and post-snap uncertainty.
- **Alarm timing despite an uncertain estimate.** A separate reachability
  bound uses an accepted anchor, elapsed time and assumed speed ceilings.
  Its conservative behavior can produce early alarms; the assumptions and
  counterexamples are part of the tests.
- **Offline braking and stop-event experiments.** Two reported handheld rides
  showed stronger braking-force magnitudes but weak signed acceleration.
  The stop detector still produced false and missed stops. A candidate
  stop-anchored model improved selected offline cases; it was not integrated
  into the live alarm path or validated across devices.
- **Failure analysis with preserved context.** Replay harnesses, diagnostic
  scripts, research notes, plots and commits explain drift, an extreme
  covariance-driven position jump, false ZUPTs and uncertain station matches.

This was substantial applied R&D, and dependable underground operation remained
unresolved. I needed better sensor recordings aligned with station-level
ground truth, across devices and phone placements, to tune and validate the
approach. Obtaining that dataset became too expensive, so I stopped pursuing
the product. This rationale was recorded in September 2026; the archive does
not establish a quoted procurement price or a calibrated final model.

[Underground evolution](UNDERGROUND_EVOLUTION.md) connects this account to
specific source, tests and historical reports. Raw recording inputs and parts
of the external analysis workspace are outside the code delivery, so the
two-ride findings remain authored research reports, not a newly reproduced
field benchmark. The record lets a buyer trace where a plausible model and
passing software tests still fell short of dependable field behavior.

## Checks and historical debugging tasks

The [successful GitHub run at `0752b78`](https://github.com/Raed2180416/GeoWake-Engineering-Archive/actions/runs/35531609869)
passed **1,423 visible Flutter cases, 61 Express tests and 16 sharing tests**.
Flutter analysis found zero errors and warnings, with 77 informational findings.
The available-code profile explicitly excludes eight dataset-dependent test
files; 210 hidden harness events are not additional tests.

Measured Flutter line coverage was **65.08%** across 133 instrumented files
(10,362 / 15,923 lines); Express was **72.66%** across 16 (303 / 417).
[Standard reports](../../coverage/README.md) include exact scope, source
revision, report hashes and source-file hashes. Subsequent CI runs publish
their own coverage artifacts and summaries. Sharing coverage and
whole-repository coverage are not measured.

The separate source before data exclusions passed 1,466 visible Flutter cases.
That is a different input scope, not a full-data pass by the cleaned package.
[Verification](VERIFICATION.md) preserves both records and the full cleaned
suite's observed failures at the excluded data boundaries.

Two [historical exercises](../../evaluation/README.md) reproduce the original
failures with unchanged historical tests:

| Task | Before the fix | After the fix |
|---|---|---|
| False ZUPT during GPS-denied cruising | 3 pass, 2 fail | 5 pass |
| Concurrent purchase restoration | 2 pass, 1 fail | 3 pass |

Each has starting source, tests, a runner, expected results, a separate
reference patch and receipts. They offer inspectable debugging tasks alongside
the broader research record. The tests do not establish live billing or
underground field accuracy.

## Delivery and proposed scope

The prepared GitHub repository, source ZIP and Git bundle contain curated
source and engineering records, feature and decision guides, source/test
indexes, preserved development/release/iOS histories, both exercises and a
112-second narrated historical development demo. The delivery manifest pins
the files and revision. Known runtime findings and unfinished work remain
documented, and iOS background behavior is incomplete.

Mixed-source metro catalogs are withheld, with labeled schema interfaces kept
for the code. Phone sensor recordings are a separate optional candidate with
their own provenance and permission questions. Users, revenue, service
accounts, signing keys, production credentials and personal communications
are outside the default delivery.

My preferred starting point is a defined **non-exclusive license** to code
and engineering records I control, with ownership retained. Price, named
recipients, permitted uses, onward disclosure, acceptance and payment timing
belong in the actual agreement. This brief makes no contractual grant or
performance warranty.

Contact: Raed Siddiqui, through the existing DataVendor conversation.
