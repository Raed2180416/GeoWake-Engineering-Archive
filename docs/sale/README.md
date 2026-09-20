# Buyer index

Prepared 20 September 2026 for licensing the existing GeoWake engineering archive
to AI-training and software-engineering buyers. Start with the
[brief](BUYER_BRIEF.md), then use the following reading paths.

## The complete journey

[Feature status matrix](FEATURES.md) is the quickest overview of implementation and limits.

[Journey and routing](JOURNEY_AND_ROUTING.md) follows destination entry, saved
trips, route selection, preflight, background handoff, progress, pre-boarding,
transfers, destination alarms, deviation, rerouting, recovery and teardown.
[Supporting systems](SUPPORTING_SYSTEMS.md) covers monetization, sharing,
guardian, anti-theft, privacy, telemetry, APIs, localization and developer tools.
[Data flow](DATA_FLOW.md) identifies producers, transformations, units, stored
state and external boundaries. The [decision register](DECISIONS.csv) links
choices to their evidence and distinguishes known intent from inference.

## What was learned

[Underground evolution](UNDERGROUND_EVOLUTION.md) connects raw IMU integration,
EKF, ZUPT, station association, reachability and the experimental stop-anchoring
pivot to dated commits and negative findings. [Founder clarifications](FOUNDER_CLARIFICATIONS.jsonl)
record the 40% pre-boarding threshold as experimental, friend-phone recording
provenance and the experimental-only stopping point.
[Engineering retrospectives](ENGINEERING_RETROSPECTIVES.md) distinguish a
verified historical regression from further task candidates.

## What can be checked

[Reproduction notes](TECHNICAL_HANDOVER.md) explain the toolchain and local
checks. [Claims](CLAIMS.csv) separates code, measured results, founder reports
and unresolved claims. The separately supplied evidence bundle contains the
exact-revision file/symbol/import/test index, verification receipts, dependency
notices, history mapping and the runnable ZUPT evaluation example. Lexical
source-to-test matches are navigation hints, not measured coverage.

## Which version

The original development baseline was `440e9003cbd3ec7ec78cea0accc56df9cb7d9b2e`
(130 reachable commits). [The local-work capture](LOCAL_WORK_CAPTURE.md)
records 119 modified files and 24 additional files, captured in `f4daa94` at
the founder's request. Subsequent small reproduction repairs are separately
committed. The prior DataVendor estimate inspected `stable-release-1`, not this
updated corpus. The delivery manifest and remote equality receipt identify the
final offered Git revision; do not use the old estimate's SHA for this package.

[Branch history](BRANCH_HISTORY.md) explains unique development/release/iOS
lines. [Document curation](DOCUMENT_CURATION.md) records the earlier audit;
[the historical index](../archive/README.md) is the current reading path.
Original history is preserved privately. The buyer export removes identified
credentials, optional raw data and excluded third-party material, with a
mapping rather than pretending those bytes were never present.

[Rights and exclusions](RIGHTS_AND_EXCLUSIONS.md) defines the delivery scope.
The transaction concerns existing material, without a further-development
commitment. The optional recording candidate has its own provenance and scope.
