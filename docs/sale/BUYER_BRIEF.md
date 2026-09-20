# GeoWake

**An archived Flutter/Android codebase for AI training and software-engineering evaluation.**

GeoWake lets a passenger choose a destination and a distance, time or metro-stop
threshold, then monitors the trip and presents a wake alert. It was developed
as a solo-led Flutter project, with Android native alarm integration and a
Node/Express backend. Development includes AI assistance; author entries are
not a team-size claim. The offered asset is the engineering work: source,
development history, experiments, design records and tests. No further product
development or deployment work is part of the proposed transaction.

## What a buyer can evaluate

- Route selection and caching, background location and route-session
  orchestration, with destination and transfer handling.
- Route-deviation detection, off-route handling and rerouting, including the
  decisions needed to reconcile changing position with an active journey.
- Underground and GPS-denied experiments: extended Kalman filtering, IMU
  measurements, zero-velocity updates (ZUPT), and route/station constraints.
- A reachability model that uses route progress, elapsed time and speed bounds
  to reason about an approaching destination.
- Full-screen alarm notifications, sound/vibration, and an Android exact-alarm
  backstop.
- Deterministic replay, route-scale and clock tests; architecture notes and
  genuine before/after debugging changes.
- Optional entitlement, journey-sharing, guardian, anti-theft and consent-gated
  aggregation components, with implementation status identified in the corpus.

The engineering value lies in the interaction between asynchronous sensors,
background Android execution, uncertain location, and an alarm that should not
be silently delayed. This makes the code and its tests potentially useful for
AI training, code comprehension, debugging and software-engineering evaluation.
Buyer demand and training suitability remain subject to the buyer's review.

## The engineering story

The founder reports that above-ground behavior worked mostly well, but reliable
underground operation remained unresolved. When general GPS-denied position
estimation proved unreliable, the research direction shifted toward using IMU
and ZUPT evidence, route structure and stops to anchor progress. This was an
evolution of the tracking approach; the archive still contains EKF code.

The final constraint was the cost of obtaining a suitable dataset to tune and
validate the measurements. The founder stopped pursuing the product rather
than committing to that collection effort. This account was provided on
20 September 2026; it is not a backdated project record.

For a training buyer, the changes of approach are part of the material: noisy
inputs, incorrect assumptions, calibration decisions, false stop detections,
regressions and the difference between a passing simulation and evidence from
a real journey. The component inventory and development chronology connect
those decisions to actual files, commits and research notes. Plans remain
labelled as plans; unfinished work is not silently presented as completed.

## Verified on 20 September 2026

The captured local fixes and subsequent reproduction repairs passed **1,466
visible Flutter tests, 61 Express tests and 16 sharing tests**, at source
revision `49a98bce5d2bcb8dc88837d8bdd21d0874ce4e7e`. Flutter analysis returned
zero errors and warnings, with 77 informational findings. The 218 hidden
harness events are excluded from the visible test count. The external real-ride
branch can return early when its recordings are absent; it is not fresh field
validation. Three literal placeholder tests are identified in the source index.

Flutter line coverage was **68.07% across the 133 instrumented files**
(11,436 / 16,800 executable lines); that source tree has 185 Dart files under
`lib/`. Express coverage was **72.66% across 16 instrumented files**
(303 / 417 lines). These denominators describe the measured files, not the
entire application's reliability. Final export checks and any effects of data
exclusions are reported separately against the actual delivered revision.

One historical ZUPT defect is independently reproduced: the same original test
has two intended failures before the fix and all five tests passing afterward.
The task, source, tests, reference patch and logs are packaged for inspection.

The cleaned export separately passed **1,423 visible Flutter cases, 61 Express
and 16 sharing tests** under the explicit code profile. Eight dataset-dependent
files are outside that profile. The generated mixed-source metro catalog is
withheld and represented by schema interfaces; see [scope](EXPORT_SCOPE.md)
and [verification](VERIFICATION.md) for the exact differences. Two historical
fail-to-pass exercises are now supplied, including concurrent restore handling.

## Corpus boundaries

The original developer reports that above-ground use worked mostly well, and
that underground consistency and dataset cost led to development stopping. The package
does not convert that experience into a measured success rate. The committed
replay inputs are synthetic; field accuracy, OEM behavior and alarm audibility
were not independently validated for this corpus. iOS background behavior is
incomplete. These are context for interpreting the code, not additional work
the seller is committing to perform.

Map and ride data need separate rights treatment. Third-party services,
production credentials, Play Console accounts, signing keys, users, revenue and
personal communications are outside the proposed default delivery.

## Proposed transaction

A defined **non-exclusive license** to the seller-controlled code and cleared
engineering records, with ownership retained, is the preferred starting point.
An asset acquisition or broader rights can be discussed as a separate scope.
Price, named recipients, permitted uses, onward disclosure, acceptance,
support and payment timing belong in the actual agreement. This brief is
descriptive and makes no contractual grant or performance warranty.

Contact: Raed Siddiqui, through the existing DataVendor conversation.
