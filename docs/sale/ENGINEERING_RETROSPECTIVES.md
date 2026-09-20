# Engineering retrospectives

Written 20 September 2026 from existing code and Git history. These are new
explanations of genuine changes, not historical tickets, reviews, or records of
a multi-person team. Both examples have observed fail-to-pass pairs; these individual historical
exercises are not a marketed benchmark dataset.

## GPS-denied cruising mistaken for a stop

Historical finding: `b1b30f5`. Pre-fix revision: `d0d76e5`.
Fix: `f956929`.

The zero-velocity detector could interpret sufficiently quiet GPS-denied
motion as a stop and pin the position estimate. The fix makes degraded-mode
zero-velocity updates depend on stricter quietness and motion corroboration.
Read `lib/core/ekf/zupt_detector.dart` alongside
`test/core/ekf/zupt_degraded_gating_test.dart`.

A proposed evaluation asks an agent to preserve true-stop handling while
preventing a quiet cruising segment from repeatedly resetting velocity. The
regression test supplies a checkable behavioral target. The historical research
also discusses real rides, but those externally referenced fixtures are absent
from this checkout, so their reported improvements are not freshly reproduced.

On 20 September 2026, the original regression test was run unchanged against
the immediate pre-fix source and the fixed source: **3 passed / 2 failed before,
5 passed afterward**. The two intended failures concern quiet degraded-mode
cruising and an insufficiently quiet stationary hint. The evidence bundle
contains the candidate task, original test, separate reference patch, setup,
source hashes and both logs. These tests do not replay the raw field ride.

## Concurrent purchase restoration

Pre-fix revision: `936d283`. Fix: `5877dee`.

The purchase backend contains coordination logic for concurrent restore calls.
Read `lib/services/monetization/purchase_backend_impl.dart` alongside
`test/monetization/purchase_backend_impl_test.dart`. The tests document the
request/response and concurrency behavior without requiring real store access.

The fix gives each caller its own waiter and delivers a stream event to each.
It does **not** coalesce store restorePurchases() calls. The unchanged original
test produced **2 passes and 1 intended failure** before (a concurrent caller
waited 3,000 ms against a <1,000 ms assertion), and **3 passes afterward**.
The standalone harness uses a fake store. Original test comments reveal the
repair, so this is a transparent historical exercise rather than a blind
benchmark. Device billing is not validated.

## Suggested evaluation delivery fields

Each accepted task should contain a new task ID, retrospective creation date,
original commit references, a natural-language problem statement, exact setup,
the test patch, observed pre-fix failure, observed post-fix success, runtime
limits, expected external services, rights scope and grading boundaries. Keep
the solution and ground-truth patch separate from agent-visible inputs.
