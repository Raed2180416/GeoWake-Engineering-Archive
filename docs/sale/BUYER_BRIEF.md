# GeoWake

**A transit alarm codebase with a substantial debugging and simulation history.**

GeoWake lets a passenger choose a destination and a distance, time or metro-stop
threshold, then monitors the trip and presents a wake alert. It was developed
as a solo-led Flutter project, with Android native alarm integration and a
Node/Express backend. Development includes AI assistance; author entries are
not a team-size claim.

## What a buyer can evaluate

- Background location and route-session orchestration, with destination and
  transfer handling.
- Sensor fusion and an extended Kalman filter for degraded GPS conditions.
- A reachability model that uses route progress, elapsed time and speed bounds
  to reason about an approaching destination.
- Full-screen alarm notifications, sound/vibration, and an Android exact-alarm
  backstop.
- Deterministic replay, route-scale and clock tests; architecture notes and
  genuine before/after debugging changes.
- Optional entitlement, journey-sharing, guardian, anti-theft and consent-gated
  aggregation components, which require their own integration review.

The engineering value lies in the interaction between asynchronous sensors,
background Android execution, uncertain location, and an alarm that should not
be silently delayed. This makes the code and its tests potentially useful for
software-engineering evaluation as well as continued product development.
Buyer demand and training suitability remain subject to the buyer's review.

## Verified on 20 September 2026

The initial committed baseline passed **1,399 visible Flutter tests**, static
analysis with informational findings, **55 Express backend tests**, and
**13 journey-sharing backend tests**. After the preparation changes, **1,400
visible Flutter tests** passed. Hidden harness events are excluded from those
counts. Real-ride branches that return early for missing external recordings
are not evidence of real-ride validation.

Measured Flutter line coverage is **67.58% across the 127 files present in the
coverage report** (10,610 / 15,699 executable lines). The repository contains
182 Dart files under `lib/`; the report does not measure every file. Backend
coverage is **76.27% across 15 instrumented files** (315 / 413 lines).
Coverage reports describe exercised code, not product reliability.

## Current product limits

The original developer reports that above-ground use worked mostly well, and
that underground consistency was the reason development stopped. The package
does not convert that experience into a measured success rate. The committed
replay inputs are synthetic; field accuracy, OEM behavior and alarm audibility
still need independent device testing. iOS background behavior is incomplete.

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
